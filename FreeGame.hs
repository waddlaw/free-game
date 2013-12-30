-----------------------------------------------------------------------------
-- |
-- Module      :  FreeGame
-- Copyright   :  (C) 2013 Fumiaki Kinoshita
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Fumiaki Kinoshita <fumiexcel@gmail.com>
-- Stability   :  provisional
-- Portability :  non-portable
----------------------------------------------------------------------------
module FreeGame
  ( -- * Main
    Game,
    runGame,
    -- * Reexports
    module FreeGame.Data.Bitmap,
    module FreeGame.Data.Font,
    module FreeGame.UI,
    module FreeGame.Util,
    module FreeGame.Text,
    module FreeGame.Types,
    module FreeGame.Class,
    module FreeGame.Instances,
    module Control.Monad,
    module Control.Applicative,
    module Control.Bool,
    module Data.Color,
    module Data.Color.Names,
    module Linear
) where

import FreeGame.UI (UI)
import FreeGame.Util
import FreeGame.Types
import FreeGame.Text
import FreeGame.Class
import FreeGame.Instances ()
import FreeGame.Data.Bitmap
import FreeGame.Data.Font
import qualified FreeGame.Backend.GLFW as GLFW
import Control.Monad.Free.Church
import Control.Monad.Trans.Iter
import Control.Monad
import Control.Applicative
import Control.Bool
import Data.Color
import Data.Color.Names
import Linear hiding (rotate)

-- | 'Game' is a monad literally expressing games.
-- This monad is an instance of 'Picture2D' so you can construct it using 'fromBitmap' and can be transformed with 'translate', 'scale', 'rotate', 'colored'.
--
-- It is also an instance of 'Keyboard' and 'Mouse'. Note that 'mousePosition' returns a relative position.
--
-- > foo = foreverTick $ do
-- >   p <- mousePosition
-- >   translate p $ colored blue $ polygonOutline [V2 (-8) (-8), V2 8 (-8), V2 8 8, V2 (-8) 8]
-- 
-- When we run @foo@ using 'runGame', a blue square follows the cursor.
-- And 'translate' (V2 240 240) @foo@, 'rotate' 45 @foo@, 'scale' 1.5 @foo@ also does in the same way.
--
-- You have to call 'tick' at the end of the frame.
--
-- The only way to embody a 'Game' as a real stuff is to apply 'runGame'.
--
-- For more examples, see <https://github.com/fumieval/free-game/tree/master/examples>.

type Game = IterT (F UI)

runGame :: IterT (F UI) a -> IO (Maybe a)
runGame = GLFW.runGame