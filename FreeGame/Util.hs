{-# LANGUAGE FlexibleContexts, TemplateHaskell #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  FreeGame.Util
-- Copyright   :  (C) 2013 Fumiaki Kinoshita
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Fumiaki Kinoshita <fumiexcel@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable
--
----------------------------------------------------------------------------

module FreeGame.Util (
    -- * Controlling
    tick,
    foreverTick,
    untick,
    untickInfinite,
    -- * Random
    randomness,
    -- * Helper
    degrees,
    radians,
    unitV2,
    angleV2,
    -- * Loading
    loadPictureFromFile,
    loadBitmaps,
    loadBitmapsWith
    ) where

import Control.Applicative
import Control.Monad
import Control.Monad.Trans
import Control.Monad.Free.Class
import Control.Monad.Trans.Iter
import Control.Monad.Free.Church
import Data.Char
import Data.Void
import FreeGame.Data.Bitmap
import FreeGame.Class
import Language.Haskell.TH
import Linear
import System.Directory
import System.FilePath
import System.IO.Unsafe
import System.Random
import System.Environment

-- | Delimit the computation to yield a frame.
tick :: (Monad f, MonadFree f m) => m ()
tick = delay (return ())

-- | An infinite loop that run 'tick' every frame after the given action.
foreverTick :: (Monad f, MonadFree f m) => m a -> m any
foreverTick m = let m' = foreverTick m in m >> wrap (return m')

-- | Extract the next frame of the action.
untick :: (Functor f, MonadFree f m) => IterT (F f) a -> m (Either (IterT (F f) a) a)
untick = liftM go . iterM wrap . runIterT where
    go (Pure a) = Right a
    go (Iter b) = Left b
    {-# INLINE go #-}

-- | An infinite version of 'untick'.
untickInfinite :: (Functor f, MonadFree f m) => IterT (F f) Void -> m (IterT (F f) Void)
untickInfinite = liftM go . iterM wrap . runIterT where
    go (Pure a) = absurd a
    go (Iter b) = b
    {-# INLINE go #-}

-- | An unit vector with the specified angle.
unitV2 :: Floating a => a -> V2 a
unitV2 t = V2 (cos t) (sin t)

-- | An angle of the given vector.
angleV2 :: RealFloat a => V2 a -> a
angleV2 (V2 a b) = atan2 b a

-- | Get a given range of value.
randomness :: (Random r, FromFinalizer m) => (r, r) -> m r
randomness r = embedIO $ randomRIO r
{-# INLINE randomness #-}

-- | Convert radians to degrees.
degrees :: Floating a => a -> a
{-# INLINE degrees #-}
degrees x = x / pi * 180

-- | Convert degrees to radians.
radians :: Floating a => a -> a
{-# INLINE radians #-}
radians x = x / 180 * pi

-- | Create a 'Picture' from the given file.
loadPictureFromFile :: (Picture2D p, FromFinalizer m) => FilePath -> m (p ())
loadPictureFromFile = embedIO . fmap bitmap . readBitmap

-- | The type of the given 'Name' must be @String -> IO String@
loadBitmapsWith :: ExpQ -> FilePath -> Q [Dec]
loadBitmapsWith getFullPath path = do
    loc <- (</>path) <$> takeDirectory <$> loc_filename <$> location
    paths <- runIO $ getFileList loc
    
    sequence $ do
        p <- paths
        let name = pathToName p
        [ return $ SigD (mkName name) (ConT ''Bitmap)
            , funD (mkName name) [clause [] (normalB $ load name $ loc </> p) []]
            ]
    where
        load name fp = do
            runIO $ putStrLn $ "Defined: " ++ fp ++ " as `" ++ name ++ "'"

            appE (varE 'unsafePerformIO) $ uInfixE (appE getFullPath $ litE $ StringL fp)
                (varE '(>>=))
                (varE 'readBitmap)

-- | Load and define all pictures in the specified directory.
loadBitmaps :: FilePath -> Q [Dec]
loadBitmaps path = do
    v <- newName "v"
    loadBitmapsWith (lamE [varP v] $
        appsE [varE 'fmap, uInfixE
                    (infixE Nothing (varE '(</>)) (Just (varE v)))
                    (varE '(.))
                    (varE 'takeDirectory)
                , varE 'getExecutablePath]) path

getFileList :: FilePath -> IO [FilePath]
getFileList path = do
    allContents <- filter notHidden `fmap` getDirectoryContents path

    files <- filterM (doesFileExist . (path</>)) allContents
    dirs <- filterM (doesDirectoryExist . (path</>)) allContents
    fmap ((files++).concat) $ forM dirs $ \i -> map (i</>) `fmap` getFileList (path</>i)
    where
        notHidden ('.':_) = False
        notHidden _ = True

pathToName :: FilePath -> String
pathToName = ('_':) . map p where
    p c | isAlphaNum c = c
        | otherwise = '_'