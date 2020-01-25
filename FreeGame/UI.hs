{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE UndecidableInstances #-}

-----------------------------------------------------------------------------

----------------------------------------------------------------------------

-- |
-- Module      :  FreeGame.UI
-- Copyright   :  (C) 2013 Fumiaki Kinoshita
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Fumiaki Kinoshita <fumiexcel@gmail.com>
-- Stability   :  provisional
-- Portability :  non-portable
-- Provides the "free" embodiment.
module FreeGame.UI
  ( UI (..),
    Drawable,
    reUI,
    reFrame,
    reGame,
    Frame,
    Game,
    FreeGame (..),
  )
where

import Control.Monad (join)
import Control.Monad.Free.Church (F, iterM)
import Control.Monad.Trans.Iter (IterT, foldM)
import Data.Color
import qualified Data.Map as Map
import FreeGame.Class
import FreeGame.Data.Bitmap (Bitmap)
import FreeGame.Internal.Finalizer
import FreeGame.Types

class (Applicative f, Monad f, Picture2D f, Local f) => Drawable f

instance (Applicative f, Monad f, Picture2D f, Local f) => Drawable f

data UI a
  = Draw (forall m. Drawable m => m a)
  | PreloadBitmap Bitmap a
  | FromFinalizer (FinalizerT IO a)
  | KeyStates (Map.Map Key ButtonState -> a)
  | MouseButtons (Map.Map Int ButtonState -> a)
  | MousePosition (Vec2 -> a)
  | MouseInWindow (Bool -> a)
  | MouseScroll (Vec2 -> a)
  | TakeScreenshot (Bitmap -> a)
  | Bracket (Frame a)
  | SetFPS Double a
  | SetTitle String a
  | ShowCursor a
  | HideCursor a
  | ClearColor (Color Float) a
  | GetFPS (Int -> a)
  | ForkFrame (Frame ()) a
  | GetBoundingBox (BoundingBox2 -> a)
  | SetBoundingBox BoundingBox2 a
  deriving (Functor)

type Game = IterT Frame

type Frame = F UI

-- | Generalize `Game` to any monad based on `FreeGame`.
reGame :: (FreeGame m, Monad m) => Game a -> m a
reGame = Control.Monad.Trans.Iter.foldM (join . reFrame)

{-# RULES "reGame/sameness" reGame = id #-}

{-# INLINE [1] reGame #-}

-- | Generalize `Frame` to any monad based on `FreeGame`.
reFrame :: (FreeGame m, Monad m) => Frame a -> m a
reFrame = iterM (join . reUI)

{-# RULES "reFrame/sameness" reFrame = id #-}

{-# INLINE [1] reFrame #-}

reUI :: FreeGame f => UI a -> f a
reUI (Draw m) = draw m
reUI (PreloadBitmap bmp cont) = cont <$ preloadBitmap bmp
reUI (FromFinalizer m) = fromFinalizer m
reUI (KeyStates cont) = cont <$> keyStates_
reUI (MouseButtons cont) = cont <$> mouseButtons_
reUI (MousePosition cont) = cont <$> globalMousePosition
reUI (MouseInWindow cont) = cont <$> mouseInWindow
reUI (MouseScroll cont) = cont <$> mouseScroll
reUI (TakeScreenshot cont) = cont <$> takeScreenshot
reUI (Bracket m) = bracket m
reUI (SetFPS i cont) = cont <$ setFPS i
reUI (SetTitle t cont) = cont <$ setTitle t
reUI (ShowCursor cont) = cont <$ showCursor
reUI (HideCursor cont) = cont <$ hideCursor
reUI (ClearColor col cont) = cont <$ clearColor col
reUI (GetFPS cont) = cont <$> getFPS
reUI (ForkFrame m cont) = cont <$ forkFrame m
reUI (GetBoundingBox cont) = cont <$> getBoundingBox
reUI (SetBoundingBox bb cont) = cont <$ setBoundingBox bb
{-# INLINE [1] reUI #-}

{-# RULES "reUI/sameness" reUI = id #-}

class (Picture2D m, Local m, Keyboard m, Mouse m, FromFinalizer m) => FreeGame m where
  -- | Draw an action that consist of 'Picture2D''s methods.
  draw :: (forall f. Drawable f => f a) -> m a

  -- | Load a 'Bitmap' to avoid the cost of the first invocation of 'bitmap'.
  preloadBitmap :: Bitmap -> m ()

  -- | Run a 'Frame', and release all the matter happened.
  bracket :: Frame a -> m a

  -- | Run a 'Frame' action concurrently. Do not use this function to draw pictures.
  forkFrame :: Frame () -> m ()

  -- | Generate a 'Bitmap' from the front buffer.
  takeScreenshot :: m Bitmap

  -- | Set the goal FPS.
  setFPS :: Double -> m ()

  setTitle :: String -> m ()
  showCursor :: m ()
  hideCursor :: m ()
  clearColor :: Color Float -> m ()

  -- | Get the actual FPS value.
  getFPS :: m Int

  getBoundingBox :: m BoundingBox2
  setBoundingBox :: BoundingBox2 -> m ()

instance FreeGame UI where
  draw = Draw
  {-# INLINE draw #-}
  preloadBitmap bmp = PreloadBitmap bmp ()
  {-# INLINE preloadBitmap #-}

  bracket = Bracket
  {-# INLINE bracket #-}
  forkFrame m = ForkFrame m ()
  takeScreenshot = TakeScreenshot id
  setFPS a = SetFPS a ()
  setTitle t = SetTitle t ()
  showCursor = ShowCursor ()
  hideCursor = HideCursor ()
  clearColor c = ClearColor c ()
  getFPS = GetFPS id
  getBoundingBox = GetBoundingBox id
  setBoundingBox s = SetBoundingBox s ()

overDraw :: (forall m. Drawable m => m a -> m a) -> UI a -> UI a
overDraw f (Draw m) = Draw (f m)
overDraw _ x = x
{-# INLINE overDraw #-}

instance Affine UI where
  translate v = overDraw (translate v)
  {-# INLINE translate #-}
  rotateR t = overDraw (rotateR t)
  {-# INLINE rotateR #-}
  rotateD t = overDraw (rotateD t)
  {-# INLINE rotateD #-}
  scale v = overDraw (scale v)
  {-# INLINE scale #-}

instance Picture2D UI where
  bitmap x = Draw (bitmap x)
  {-# INLINE bitmap #-}
  bitmapOnce x = Draw (bitmapOnce x)
  {-# INLINE bitmapOnce #-}
  line vs = Draw (line vs)
  polygon vs = Draw (polygon vs)
  polygonOutline vs = Draw (polygonOutline vs)
  circle r = Draw (circle r)
  circleOutline r = Draw (circleOutline r)
  thickness t = overDraw (thickness t)
  {-# INLINE thickness #-}
  color c = overDraw (color c)
  {-# INLINE color #-}
  blendMode m = overDraw (blendMode m)
  {-# INLINE blendMode #-}

instance Local UI where
  getLocation = Draw getLocation

instance FromFinalizer UI where
  fromFinalizer = FromFinalizer
  {-# INLINE fromFinalizer #-}

instance Keyboard UI where
  keyStates_ = KeyStates id

instance Mouse UI where
  globalMousePosition = MousePosition id

  -- mouseWheel = MouseWheel id
  mouseButtons_ = MouseButtons id
  mouseInWindow = MouseInWindow id
  mouseScroll = MouseScroll id
