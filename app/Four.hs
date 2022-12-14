{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE UnicodeSyntax #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE NumDecimals #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# HLINT ignore "Use if" #-}
{-# HLINT ignore "Redundant if" #-}
{-# HLINT ignore "Use newtype instead of data" #-}
{-# OPTIONS_GHC -Wno-incomplete-patterns #-}

module Four where


--                             LIBS                            --
------------------------------------------------------------------------
import Data.Char ()
import Data.Foldable (toList)
import Data.List (elemIndex, transpose)
import Data.Maybe as Maybe ( Maybe(Just, Nothing), fromJust )
import Data.Sequence (fromList)
import qualified Data.Sequence as Seq
import System.IO (hSetBuffering, stdin, BufferMode (NoBuffering), hSetEncoding, utf8, stdout)
import System.Random (getStdGen, newStdGen, Random (randomRs, randomR), randomRIO, randomIO, mkStdGen, RandomGen, StdGen)
import Control.Monad.State
    ( lift,
      StateT,
      evalStateT,
      MonadTrans(lift),
      MonadState(get, put),
      StateT,
      MonadIO )
import Control.Monad.Trans ( MonadTrans(lift), MonadIO )
import Control.Lens ( (^?), element, (^.), use)
import Control.Lens.Tuple ()
import Unicode.Char ()
import Text.Show.Unicode ()
import Control.Concurrent ( threadDelay )
import System.Console.ANSI
     ( setCursorPosition,
     clearScreen,
     setSGR,
     SGR (SetColor, Reset),
     ConsoleLayer (Background, Foreground),
     ColorIntensity (Vivid, Dull), Color (Blue, Red, Yellow, Green),
     getCursorPosition )
import Text.Read (readMaybe)


--                             TYPES/DATA                            --
------------------------------------------------------------------------

type Size = Int
data Disc = X | O | E deriving (Eq, Read, Show)
type Row = [Disc]
type Board = [[Disc]]
type Columns = [[Disc]]
data Maybe a = Nothing | Just a
data Game = Game
  { _gPlayer1Score    :: Int
  , _gPlayer2Score    :: Int
  , _gComputerScore   :: Int
  ,_gPlayAmountOfSets :: Int
  } deriving Show


--                            BOARD FUNCTIONS                         --
------------------------------------------------------------------------

createBoard :: Size -> Size -> Board
createBoard m n = replicate m (replicate n E)

switchPlayer :: Disc -> Disc
switchPlayer X = O
switchPlayer O = X

toDisc :: Char -> Disc
toDisc 'X' = X
toDisc 'O' = O

showPlayerName :: Disc -> String
showPlayerName X = "Player 1"
showPlayerName O = "Player 2"

playerOneInput :: IO () -> Int -> Row -> [Disc]
playerOneInput p n r = toList $ Seq.update n X (Seq.fromList r)

playerTwoInput :: IO () -> Int -> Row -> [Disc]
playerTwoInput p n r = toList $ Seq.update n O (Seq.fromList r)

-- takes a reverse board
updateBoard :: Disc -> Int -> Board -> Board
updateBoard p i [] = []
updateBoard p i (xs : xss) = case xs ^? element i of
    Maybe.Nothing -> xs : xss
    Maybe.Just E  -> if p == X then playerOneInput (showDisc p) i xs : xss else playerTwoInput (showDisc p) i xs : xss
    Maybe.Just X  -> xs : updateBoard p i xss
    Maybe.Just O  -> xs : updateBoard p i xss

showBoard :: Board -> IO ()
showBoard = do mapM_ initRow

-- showDisc :: Disc -> IO ()
-- showDisc E = putChar 'E'
-- showDisc X = setSGR [SetColor Foreground  Vivid Blue] >> putChar 'X' >> setSGR [Reset]
-- showDisc O = setSGR [SetColor Foreground  Vivid Red] >> putChar 'O' >> setSGR [Reset]

-- use this when on linux or have windows set on Unicode support
showDisc :: Disc -> IO()
showDisc E =  putChar '???'
showDisc X =  putChar '????'
showDisc O =  putChar '????'

initRow :: Row -> IO ()
initRow []  = putStrLn "There are no rows inserted"
initRow [x] = showDisc x >> putStr "\n"
initRow (x : xs) = showDisc x >> putChar ' ' >> initRow xs

columnHasEmptySlot :: [[Disc]] -> Int -> Bool
columnHasEmptySlot b i = find E $ map (!!i) b

getColumn :: [[b]] -> Int -> [b]
getColumn b i = map (!!i) b

getAvailableColumnIndexes :: [[Disc]] -> Int -> [[Int]]
getAvailableColumnIndexes (xs : xss) ci =
  if ci < length xs then
    case columnHasEmptySlot (xs : xss) ci of
      True -> [ci] : getAvailableColumnIndexes (xs : xss) (ci + 1)
      False -> getAvailableColumnIndexes (xs : xss) (ci + 1) else []



--                            PLAYER WIN LOGIC                       --
------------------------------------------------------------------------

winOnStraightLine :: Disc -> Row -> Bool
winOnStraightLine p [] = False
winOnStraightLine p [x,y,z] = False
winOnStraightLine p r = (filter (== p) (take 4 r)  == take 4 r) || winOnStraightLine p (tail r)

leftdiagonals :: Board-> Board
leftdiagonals [] = []
leftdiagonals ([] : x) = x
leftdiagonals  x = zipWith (++) (map ( (: []). head) x ++ repeat [])([]:leftdiagonals (map tail x))

rightdiagonals :: Board -> Board
rightdiagonals x = leftdiagonals (reverse x)

moreThanThree :: [[a]] -> [[a]]
moreThanThree x = filter (\x-> (length x) >3) x

diagonals ::  Board -> Board
diagonals x = moreThanThree (leftdiagonals x ++ rightdiagonals x)

winDiagonalsPlayerOne :: Board -> Bool
winDiagonalsPlayerOne b = winRowBoardPlayerOne ( diagonals b)

winRowBoardPlayerOne :: Board -> Bool
winRowBoardPlayerOne b = if filter (== True)( map (winRowPlayerOne) b) == [] then False else True

winRowPlayerOne :: Row -> Bool
winRowPlayerOne [] = False
winRowPlayerOne [x,y,z] = False
winRowPlayerOne r = if  filter (== X) (take 4 r)  == take 4 r then True else winRowPlayerOne (tail r)

winRowBoardPlayerTwo :: Board -> Bool
winRowBoardPlayerTwo b = if filter (== True)( map (winRowPlayerTwo) b) == [] then False else True

winDiagonalsPlayerTwo :: Board -> Bool
winDiagonalsPlayerTwo x = winRowBoardPlayerTwo ( diagonals x)

winRowPlayerTwo :: Row -> Bool
winRowPlayerTwo [] = False
winRowPlayerTwo [x,y,z] = False
winRowPlayerTwo r = if  filter (== O) (take 4 r)  == take 4 r then True else winRowPlayerTwo (tail r)

isDraw :: Board -> Bool
isDraw [] = True
isDraw (b:bs) =  if filterE b  /= [] then False else isDraw bs

winRowBoardPlayer:: Disc -> Board -> Bool
winRowBoardPlayer p b = if filter (== True)( map (winOnStraightLine p ) b) == [] then False else True


winDiagonals :: Disc -> Board -> Bool
winDiagonals p b = winRowBoardPlayer p ( diagonals b)


--                            USER/COMPUTER INPUT                      --
------------------------------------------------------------------------

getUserInput :: String -> IO Int
getUserInput s = do
  putStrLn s
  line <- getLine
  case readMaybe line of
    Maybe.Just x -> return x
    Maybe.Nothing -> putStrLn "You must enter a valid number. Please try again. \n" >> getUserInput s

getColumnFromUser :: Disc -> Board -> IO Int
getColumnFromUser p b = do
  spacer
  let availableIndexes = concat $ getAvailableColumnIndexes b 0
  let indexesUserFriendly = map (+1) availableIndexes
  putStr (showPlayerName p) >> putStr " choose input column from range: " >> print indexesUserFriendly
  i <- getUserInput ""
  if i < (length (head b) + 1)
    then return (i - 1)
    else putStrLn "You must enter a valid number. Please try again. \n" >> getColumnFromUser p b

computerMove :: [a] -> IO a
computerMove l = do
  gen <- newStdGen
  randomElement gen l

randomElement :: RandomGen g => g -> [a] -> IO a
randomElement rnd list = do
    gen <- getStdGen
    let (i, _) = randomR (0, length list - 1) gen
    return $ list !! i

setCollumnFromUser :: IO Int
setCollumnFromUser  = do 
  spacer 
  putStrLn $ "Choose a board size column: \n" ++ "Columns: "
  c <- getUserInput "" 
  if c < 4 
    then putStrLn " You must enter a number equal or higher than 4 . Please try again. \n" >> setCollumnFromUser 
    else return c
    
    
setRowFromUser ::  IO Int 
setRowFromUser = do
  spacer 
  putStrLn "Rows: "
  r <- getUserInput "" 
  if r < 4 
    then putStrLn "You must enter a number equal or higher than 4. Please try again. \n"  >>  setRowFromUser 
    else return r


--                           GAMEPLAY                      --
------------------------------------------------------------------------


checkWinner :: Int -> Int -> Int -> Int -> Disc -> Int -> Board -> StateT Game IO ()
checkWinner m c r s p i rb = do
  game <- get
  let ps1  = _gPlayer1Score game
      ps2  = _gPlayer2Score game
      gs   = _gPlayAmountOfSets game
  if winOnStraightLine  p $ getColumn (updateBoard p i rb) i then case p == X of
    True -> do
               lift $ putStrLn "Player 1 has won!"
               lift $ spacer
               if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1+1) (ps2) (gs+1) else do
               let currentSet = gs + 1
               lift $ putStrLn "-----------------------------------------------------------------------"
               newGame <- mkNewGame p ps1 ps2 gs
               lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
    False -> do 
                lift $ putStrLn "Player 2 has won!"
                lift $ spacer
                if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >>  putStrLn "END RESULT: " >> showScore (ps1) (ps2+1) (gs+1) else do
                let currentSet = gs + 1
                lift $ putStrLn "-----------------------------------------------------------------------"
                newGame <- mkNewGame p ps1 ps2 gs
                lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
                else if winOnStraightLine p (concat $ updateBoard p i rb) then case p == X of
    True -> do
               lift $ putStrLn "Player 1 has won!"
               lift $ spacer
               if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >>  putStrLn "END RESULT: " >> showScore (ps1+1) (ps2) (gs+1) else do
               let currentSet = gs + 1
               lift $ putStrLn "-----------------------------------------------------------------------"
               newGame <- mkNewGame p ps1 ps2 gs
               lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
    False -> do
                lift $ putStrLn "Player 2 has won!"
                lift $ spacer
                if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >>  putStrLn "END RESULT: " >> showScore (ps1) (ps2+1) (gs+1) else do
                lift $ putStrLn "-----------------------------------------------------------------------"
                let currentSet = gs + 1
                newGame <- mkNewGame p ps1 ps2 gs
                lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
                else if winDiagonalsPlayerOne (updateBoard p i rb)
    then case p == X of
     True -> do
                lift $ putStrLn "Player 1 has won !"
                lift $ spacer
                if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >>  showScore (ps1+1) (ps2) (gs+1) else do
                lift $ putStrLn "-----------------------------------------------------------------------"
                let currentSet = gs + 1
                newGame <- mkNewGame p ps1 ps2 gs
                lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
     False -> do
                lift $ spacer
                else if winDiagonalsPlayerTwo (updateBoard p i rb)
    then case p == O of
     True -> do
                lift $ putStrLn "Player 2 has won!"
                lift $ spacer
                if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >>  putStrLn "END RESULT: " >> showScore (ps1) (ps2+1) (gs+1) else do
                lift $ putStrLn "-----------------------------------------------------------------------"
                let currentSet = gs + 2
                newGame <- mkNewGame p ps1 ps2 gs
                lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
                 else if isDraw (updateBoard p i rb)
    then do
            lift $ putStrLn "The game ended in a draw" else if gs < s && m == 1 then playGameP m c r s (switchPlayer p) (reverse $ updateBoard p i rb)
  else if gs < s && m == 2 then playGameC m c r s (switchPlayer p) (reverse $ updateBoard p i rb)
  else lift $ putStrLn ""


showScore :: Int -> Int -> Int -> IO()
showScore ps1 ps2 s= do putStrLn $ "Round: " ++ show s ++ " | " ++ "Player 1 Score : " ++ show ps1
                        putStrLn $ "Round: " ++ show s ++ " | " ++ "Player 2 Score : " ++ show ps2

playGameP :: Int -> Int -> Int -> Int -> Disc -> Board -> StateT Game IO ()
playGameP m c r s p b = do
  game <- get
  let ps1 = _gPlayer1Score game
  let ps2 = _gPlayer2Score game
  let gs     = _gPlayAmountOfSets game
  lift $ spacer
  lift $ showScore ps1 (ps2) (gs+1)
  lift $ spacer
  lift $ spacer
  lift $ setSGR [SetColor Foreground  Vivid Green]
  putStrLnIo $ "CURRENT ROUND: " ++ show (gs + 1)
  lift $ setSGR [Reset]
  i <- lift $ getColumnFromUser p b
  lift $ threadDelay 2.0e5
  let rb = reverse b
  if columnHasEmptySlot rb i then lift $ showBoard (reverse $ updateBoard p i rb) else lift $ putStrLn "Column is full, please choose another column"
  let ri = reverse rb
  checkWinner m c r s p i rb  

playGameC :: Int -> Int -> Int -> Int -> Disc -> Board -> StateT Game IO ()
playGameC m c r s p b = do
  game <- get
  let player1Score  = _gPlayer1Score game
      computerScore = _gComputerScore game
      gameSets      = _gPlayAmountOfSets game
  lift $ putStrLn $ "Player 1 Score:" ++ show player1Score
  lift $ putStrLn $ "Computer Score:" ++ show computerScore
  lift $ threadDelay 1000000
  let availableIndexes = concat $ getAvailableColumnIndexes b 0
  lift $ spacer
  number <- lift $ computerMove availableIndexes
  lift $ putStr "Computer made move in column:" >> print (number + 1)
  let rb = reverse b
  lift $ showBoard (reverse $ updateBoard p number rb)
  let rbr2 = reverse $ updateBoard p number rb
  checkComputerWin m c r s p rbr2 

checkComputerWin :: Int -> Int -> Int -> Int -> Disc -> Board -> StateT Game IO ()
checkComputerWin m c r s p b = do
  game <- get
  let ps1 = _gPlayer1Score game
  let cs2 = _gComputerScore game
  let gs  = _gPlayAmountOfSets game
  if winRowBoardPlayer O (transpose b) 
    then do 
            lift $ putStrLn "Computer has won!"
            lift $ spacer
            if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1) (cs2+1) (gs+1) else do
            let currentSet = gs + 1
            lift $ putStrLn "-----------------------------------------------------------------------"
            newGame <- mkNewGame p ps1 cs2 gs
            lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
    else if winRowBoardPlayer O b == True 
       then do 
           lift $ putStrLn "Computer has won!"
           lift $ spacer
           if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1) (cs2+1) (gs+1) else do
           let currentSet = gs + 1
           lift $ putStrLn "-----------------------------------------------------------------------"
           newGame <- mkNewGame p ps1 cs2 gs
           lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
    else if winDiagonals O b == True
      then do 
          lift $ putStrLn "Computer has won!"
          lift $ spacer
          if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1) (cs2+1) (gs+1) else do
          let currentSet = gs + 1
          lift $ putStrLn "-----------------------------------------------------------------------"
          newGame <- mkNewGame p ps1 cs2 gs
          lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
     else if isDraw b
       then do
            lift $ putStrLn "The game ended in a draw" 
     else playGameP m c r s (switchPlayer p) b
       
-- checkComputerWin :: Int -> Int -> Int -> Int -> Disc -> Board -> StateT Game IO ()
--checkComputerWin m c r s p b = do
  --game <- get
--  let ps1 = _gPlayer1Score game
--  let cs2 = _gComputerScore game
--  let gs  = _gPlayAmountOfSets game
--  if winRowBoardPlayer O (transpose b) == True
--    then do 
--            lift $ putStrLn "Computer has won!"
--            lift $ spacer
--            if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1) (cs2+1) (gs+1) else do
--            let currentSet = gs + 1
--            lift $ putStrLn "-----------------------------------------------------------------------"
--            newGame <- mkNewGame p ps1 cs2 gs
--            lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
--    else if winRowBoardPlayer O b == True 
--       then do 
--           lift $ putStrLn "Computer has won!"
--           lift $ spacer
--           if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1) (cs2+1) (gs+1) else do
--           let currentSet = gs + 1
--           lift $ putStrLn "-----------------------------------------------------------------------"
--           newGame <- mkNewGame p ps1 cs2 gs
--           lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
--    else if winDiagonals O b == True
--      then do 
--          lift $ putStrLn "Computer has won!"
--          lift $ spacer
--          if (gs+1) >= s then lift $ putStrLn "THE GAME HAS ENDED! Congratulations! ????" >> putStrLn "END RESULT: " >> showScore (ps1) (cs2+1) (gs+1) else do
--          let currentSet = gs + 1
--          lift $ putStrLn "-----------------------------------------------------------------------"
--          newGame <- mkNewGame p ps1 cs2 gs
--          lift $ evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
--     else if isDraw b
--       then do
--            lift $ putStrLn "The game ended in a draw" 
--     else playGameP m c r s (switchPlayer p) b

initializeGame :: IO ()
initializeGame = do
      hSetEncoding stdout utf8
      hSetBuffering stdin NoBuffering
      clearScreen
      setCursorPosition 4 25
      setSGR [SetColor Foreground  Vivid Blue]
      putStrLn "WELCOME TO 4 IN A ROW"
      setSGR [Reset]
      m <- getUserInput $ "Choose a game mode: \n"++ "1 -> Player vs Player \n" ++ "2 -> Player vs Computer"
      t <- getUserInput $ "Choose the type of board you want to play with: \n"++ "1 -> Standard Board \n" ++ "2 -> Customize your own board"
      if t == 1
      then do 
             s <- getUserInput "How many rounds do you want to play? : [1-5] "
             let c = 6 
                 r = 7 
             showBoard $ createBoard c r
             newGame <- initGame
             evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
      else do
            c <- setCollumnFromUser 
            r <- setRowFromUser
            s <- getUserInput "How many rounds do you want to play? : [1-5] "
            showBoard $ createBoard c r
            newGame <- initGame
            evalStateT (playGameP m c r s X (createBoard c r)) $ newGame
 

main :: IO ()
main = do
  initializeGame
  return ()

  
mkNewGame :: MonadIO m => Disc -> Int -> Int -> Int -> m Game
mkNewGame p ps1 ps2 set = do
                             if p == X
                             then return $ Game {_gPlayer1Score = ps1 + 1, _gPlayer2Score = ps2 ,_gComputerScore = 0, _gPlayAmountOfSets = set + 1}
                             else return $ Game {_gPlayer1Score = ps1, _gPlayer2Score = ps2 + 1,_gComputerScore = 0, _gPlayAmountOfSets = set + 1}

                             
initGame :: MonadIO m => m Game
initGame = do
  return $ Game
    { _gPlayer1Score     = 0
    , _gPlayer2Score     = 0
    , _gComputerScore    = 0
    , _gPlayAmountOfSets = 0
      }

--                           HELPER FUNCTIONS                      --
------------------------------------------------------------------------

filterE :: [Disc] -> [Disc]
filterE y = filter (== E) y

find :: Eq t => t -> [t] -> Bool
find _ [] = False
find n (x:xs)
  | x == n = True
  | otherwise = find n xs

spacer :: IO ()
spacer = do putStrLn " "

putStrLnIo :: String -> StateT Game IO ()
putStrLnIo = lift.putStrLn