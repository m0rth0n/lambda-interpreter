-- Lambda Calculus Interpreter, Version 0.1.4

import System.IO
import Data.Char

-- DATA DEFINITIONS

type Variable = (Char, Integer)

data Expr = Singleton Variable
          | Application Expr Expr
          | Lambda Variable Expr
          deriving Eq

instance Show Expr where
    show (Singleton (v, 0)) = [v]
    show (Singleton (v, i)) = [v, '_'] ++ (show $ i - 1)
    show (Application e1@(Application _ _) e2) = (init $ show e1) ++ " " 
                                               ++ show e2 ++ ")"
    show (Application e1 e2) = "(" ++ (show e1) ++ " " ++ (show e2) ++ ")"
    show (Lambda v e@(Lambda _ _)) = "(λ" ++ (show (Singleton v)) 
                                   ++ (tail $ tail $ show e)
    show (Lambda v e) = "(λ" ++ (show (Singleton v)) ++ "." ++ show e ++ ")"

data Error = IllegalChar Char
           | ParseError
           deriving Eq

instance Show Error where
    show e = "Error: " ++ case e of
                           ParseError    -> "no parse"
                           IllegalChar c -> "illegal use of character '"
                                            ++ (c:"'")

-- EVALUATOR

rename :: Variable -> Variable
rename = fmap (+1)

evalLambda :: Expr -> Expr
evalLambda (Application e1 e2) = case e1 of
  (Application (Singleton v) e) -> Application 
                                     (Application (Singleton v) $ evalLambda e)
                                     e2
  (Application _ _)             -> if (e1 == evalLambda e1)
                                     then Application e1 e2
                                     else evalLambda 
                                       $ Application (evalLambda e1) e2
  (Singleton v)                 -> Application (Singleton v) (evalLambda e2)
  (Lambda v e)                  -> evalLambda $ replaceByIn v e2 e
evalLambda (Lambda v e)        = (Lambda v $ evalLambda e)
evalLambda (Singleton v)       = (Singleton v)

-- replace by in is Beta-equivalence
replaceByIn :: Variable -> Expr -> Expr -> Expr
replaceByIn v e (Singleton w)       = if v == w 
                                      then e
                                      else Singleton w
replaceByIn v e (Application e1 e2) = Application (replaceByIn v e e1)
                                                  (replaceByIn v e e2)
replaceByIn v e (Lambda w e1)       = if v == w || w `isFreeIn` e
                                      then replaceByIn v e
                                             (Lambda (rename w)
                                                     (replaceByIn w 
                                                       (Singleton (rename w))
                                                       e1))
                                      else Lambda w (replaceByIn v e e1)

-- Tests wether a variable is free or bound in an expression
isFreeIn :: Variable -> Expr -> Bool
isFreeIn v (Singleton w)       = v == w
isFreeIn v (Lambda w e)        = (v /= w) && v `isFreeIn` e
isFreeIn v (Application e1 e2) = (v `isFreeIn` e1) || (v `isFreeIn` e2)

-- PARSER

forbidden :: Char -> Bool
forbidden v = v `elem` "_ ()\\" || isNumber v

parseLambda :: String -> Either Error Expr
-- Single variable
parseLambda [v]                = if forbidden v
                                 then Left  $ IllegalChar v
                                 else Right $ Singleton (v, 0)
parseLambda ('(':v:")")        = parseLambda [v]
-- Single parameter lambda expression
parseLambda ('(':'\\':v:'.':e) = if forbidden v 
                                 then Left $ IllegalChar v
                                 else Lambda (v, 0) <$> (parseLambda $ addParens
                                                                   $ init e)
-- Multiple parameters lambda expression
parseLambda ('(':'\\':v:e)     = if forbidden v
                                 then Left $ IllegalChar v
                                 else Lambda (v, 0) <$> (parseLambda $ "(\\"
                                                                     ++ e)
-- Application. There can be multiple arguments.
parseLambda ('(':s)            = Application <$> (fst splitted)
                                             <*> (snd splitted)
                  where splitted = ( parseLambda (addParens $ take (m-2) 
                                                            $ init s)
                                   , parseLambda (drop (m-1) $ init s))
                        n        = length $ takeWhile (/= 0) $ tail $ scanl f 0
                                   $ reverse $ init s
                        m        = (length $ init s) - n
                        f :: Integer -> Char -> Integer
                        f n c    = case c of
                                     '(' -> n+1
                                     ')' -> n-1
                                     otherwise -> n
parseLambda _                  = Left ParseError

-- Adds parenthesis around an expression if needed
addParens :: String -> String
addParens "" = ""
addParens s = if head s == '\\' || checkApps 0 s
              then '(':(s ++ ")")
              else s
  where checkApps :: Integer -> [Char] -> Bool
        checkApps 0 (' ':_)  = True
        checkApps _ []       = False
        checkApps n ('(':cs) = checkApps (n+1) cs
        checkApps n (')':cs) = checkApps (n-1) cs
        checkApps n (_:cs)   = checkApps n cs

-- TODO :
--  * Enable combinator definitions and reading them from a file.
--  ! Ensure that there are no infinite loops or evaluation errors

-- IO

-- Clear the screen and go back to the top.
clear :: IO ()
clear = putStr "\x1b[2J\x1b[0;0H"

repl :: IO ()
repl = do hSetBuffering stdin LineBuffering
          hSetBuffering stdout NoBuffering
          putStr "λ> "
          s <- getLine
          case words s of
            []         -> repl
            ":quit":_  -> return ()
            ":q":_     -> return ()
            ":h":_     -> printHelp >> repl
            ":help":_  -> printHelp >> repl
            ":clear":_ -> clear >> repl
            ":cls":_   -> clear >> repl
            otherwise  -> case (parseLambda $ addParens $ unwords $ words s) of
                           Right l -> do putStr $ show l
                                         putStr " = "
                                         print $ evalLambda l
                                         repl
                           Left  e -> do print e >> repl

main :: IO ()
main = do putStrLn "Lambda Calculus Interpreter"
          putStrLn "Version: 0.1.4"
          putStrLn "Build Date: February 4nd, 2018"
          putStrLn "Type :help or :h for help and information on commands"
          repl

printHelp :: IO ()
printHelp = readFile "help.txt" >>= putStr

-- Some lambda terms for testing in GHCi

lnumber :: Int -> Expr
lnumber n = (Lambda ('f', 0)
                    (Lambda ('x', 0) (loop n)))
            where loop 0 = Singleton ('x', 0)
                  loop n = Application (Singleton ('f', 0)) $ loop (n-1)

lpair = (Lambda ('n', 0)
                (Lambda ('m', 0)
                        (Lambda ('f', 0)
                                (Application (Application (Singleton ('f', 0))
                                                          (Singleton ('n', 0)))
                                             (Singleton ('m', 0))))))

lmult = (Lambda ('n', 0) (Lambda ('m', 0) (Lambda ('f', 0)
                (Application (Singleton ('m', 0))
                             (Application (Singleton ('n', 0))
                                          (Singleton ('f', 0)))))))
lpred =  Lambda ('n', 0) (Lambda ('f', 0) 
                         (Lambda ('x', 0) 
                         (Application 
                           (Application 
                             (Application (Singleton ('n', 0)) 
                                          (Lambda ('g', 0)
                                            (Lambda ('h', 0)
                                              (Application
                                                 (Singleton ('h', 0))
                                                 (Application 
                                                   (Singleton ('g', 0)) 
                                                   (Singleton ('f', 0)))))))
                             (Lambda ('u', 0) (Singleton ('x', 0))))
                           (Lambda ('u', 0) (Singleton ('u', 0))))))

ltrue  = Lambda ('x', 0) (Lambda ('y', 0) (Singleton ('x', 0)))
lfalse = Lambda ('x', 0) (Lambda ('y', 0) (Singleton ('y', 0)))

liszero = (Lambda ('n', 0)
                  (Application (Application (Singleton ('n', 0))
                                 (Lambda ('v', 0) (lfalse)))
                               ltrue))

-- I'm too lazy to type all that expression down :)
lY = case parseLambda "(\\f.(\\x.f (x x)) (\\x.f (x x)))" of
      Right e1 -> e1

lfactorial = Application lY lH
lH = Lambda ('f', 0)
            (Lambda ('n', 0)
                    (Application
                       (Application (Application liszero (Singleton ('n', 0))) 
                         (lnumber 1))
                       (Application 
                         (Application lmult (Singleton ('n', 0))) 
                         (Application 
                           (Singleton ('f', 0))
                           (Application lpred (Singleton ('n', 0)))))))
