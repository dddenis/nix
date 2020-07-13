import           Control.Monad                  ( forM_ )
import           Data.List                      ( sortBy )
import           Data.Function                  ( on )
import           XMonad
import           XMonad.Config.Desktop          ( desktopConfig )
import           XMonad.Hooks.EwmhDesktops      ( ewmh
                                                , fullscreenEventHook
                                                )
import qualified XMonad.StackSet               as W
import           XMonad.Util.Replace            ( replace )
import           XMonad.Util.Run                ( safeSpawn )

main :: IO ()
main = do
  replace

  forM_ [".xmonad-workspace-log", ".xmonad-layout-log"]
    $ \file -> safeSpawn "mkfifo" ["/tmp/" ++ file]

  xmonad . ewmh $ myConfig

myConfig = desktopConfig
  { terminal           = "@terminal@"
  , modMask            = mod4Mask
  , normalBorderColor  = "@normalBorderColor@"
  , focusedBorderColor = "@focusedBorderColor@"
  , handleEventHook    = handleEventHook desktopConfig <+> fullscreenEventHook
  , logHook            = logHook desktopConfig <+> myLogHook
  }

myLogHook :: X ()
myLogHook = do
  windowSet <- gets windowset

  let currentWorkspaceTag = W.currentTag windowSet
  let workspaceTags       = W.tag <$> W.workspaces windowSet
  let workspaceTagStrings =
        formatWorkspaces currentWorkspaceTag =<< sortWorkspaces workspaceTags

  io $ appendFile "/tmp/.xmonad-workspace-log" (workspaceTagStrings ++ "\n")

  let currentLayout =
        formatLayout
          . description
          . W.layout
          . W.workspace
          . W.current
          $ windowSet

  io $ appendFile "/tmp/.xmonad-layout-log" (currentLayout ++ "\n")

 where
  formatWorkspaces currentTag tag
    | currentTag == tag
    = "[%{F@currentWorkspaceColor@}%{T2}" ++ tag ++ "%{T-}%{F@workspaceColor@}]"
    | otherwise
    = " " ++ tag ++ " "

  sortWorkspaces = sortBy (compare `on` (!! 0))

  formatLayout layout | layout == "Three Columns"    = "%{T2}+|+%{T-} TCM "
                      | layout == "Binary Partition" = "%{T2}||+%{T-} BSP "
                      | layout == "Tall"             = "%{T2}|||%{T-} Tall"
                      | layout == "Tabbed"           = "%{T2}___%{T-} Tab "
                      | layout == "Float"            = "%{T2}+++%{T-} FLT "
                      | layout == "Fullscreen"       = "%{T2}| |%{T-} Full"
                      | otherwise                    = layout
