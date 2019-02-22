{-|
Module      : EasyTest
Copyright   : (c) Joel Burget, 2018-2019
License     : MIT
Maintainer  : joelburget@gmail.com
Stability   : provisional

EasyTest is a simple testing toolkit, meant to replace most uses of QuickCheck, SmallCheck, HUnit, and frameworks like Tasty, etc. Here's an example usage:

@
module Main where

import           EasyTest
import qualified Hedgehog.Gen   as Gen
import qualified Hedgehog.Range as Range

suite :: Test
suite = tests
  [ 'scope' "addition.ex1" $ 'unitTest' $ 1 + 1 '===' 2
  , 'scope' "addition.ex2" $ 'unitTest' $ 2 + 3 '===' 5
  , 'scope' "list.reversal" $ 'propertyTest' $ do
      ns @<-@ 'forAll' $
        Gen.list (Range.singleton 10) (Gen.int Range.constantBounded)
      reverse (reverse ns) '===' ns
  -- equivalent to `scope "addition.ex3"`
  , 'scope' "addition" . 'scope' "ex3" $ 'unitTest' $ 3 + 3 '===' 6
  , 'scope' "always passes" $ 'ok' -- record a success result
  , 'scope' "failing test" $ 'crash' "oh noes!!"
  ]

-- NB: `run suite` would run all tests, but we only run
-- tests whose scopes are prefixed by "addition"
main :: IO ()
main = 'runOnly' "addition" suite
@

This generates the output:

> ━━━ runOnly "addition" ━━━
>   ✓ addition.ex1 passed 1 test.
>   ✓ addition.ex2 passed 1 test.
>   ⚐ list.reversal gave up after 1 discard, passed 0 tests.
>   ✓ addition.ex3 passed 1 test.
>   ⚐ always passes gave up after 1 discard, passed 0 tests.
>   ⚐ failing test gave up after 1 discard, passed 0 tests.
>   ⚐ 3 gave up, 3 succeeded.

The idea here is to write tests with ordinary Haskell code, with control flow explicit and under programmer control.

= User guide

The simplest tests are 'ok', 'crash', and 'expect':

@
-- Record a success
'ok' :: 'Test'

-- Record a failure
'crash' :: String -> 'Test'

-- Record a success if True, otherwise record a failure
'expect' :: Bool -> 'Test'
@

We often want to label tests so we can see when they succeed or fail. For that we use 'scope':

@
-- | Label a test. Can be nested. A `'.'` is placed between nested
-- scopes, so `scope "foo" . scope "bar"` is equivalent to `scope "foo.bar"`
'scope' :: String -> 'Test' -> 'Test'
@

Here's an example usage, putting all these primitives together:

@
module Main where

import EasyTest (Test, ok, scope, crash, expect, run, tests)

suite :: 'Test'
suite = 'tests'
  [ 'ok'
  , 'scope' "test-crash" $ 'crash' "oh noes!"
  , 'expect' $ 1 + 1 == 2
  ]

main :: Main
main = 'run' suite
@

This example is sequencing the 'ok', 'crash', and 'expect', so that they're all tested. The output is:

> ━━━ run ━━━
>   ✓ (unnamed) passed 1 test.
>   ✗ test-crash failed after 1 test.
>
>         ┏━━ src/EasyTest/Internal.hs ━━━
>     262 ┃ crash :: HasCallStack => String -> Test
>     263 ┃ crash msg = Leaf $ unitProperty $ do { footnote msg; failure }
>         ┃ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
>
>     oh noes!
>
>     This failure can be reproduced by running:
>     > recheck (Size 0) (Seed 13981450739178025187 12313316183895066259) test-crash
>
>   ✓ (unnamed) passed 1 test.
>   ✗ 1 failed, 2 succeeded.
> *** Exception: ExitFailure 1

In the output, we get a stack trace pointing to the line where crash was called (@..tests/Suite.hs:10:24@), information about failing tests, and instructions for rerunning the tests with an identical random seed (in this case, there's no randomness, so @rerun@ would work fine, but if our test generated random data, we might want to rerun with the exact same random numbers).

The various run functions ('run', 'runOnly', 'rerun', and 'rerunOnly') all exit the process with a nonzero status in the event of a failure, so they can be used for continuous integration or test running tools that key off the process exit code to determine whether the suite succeeded or failed. For instance, here's the relevant portion of a typical cabal file:

@
test-suite tests
  type:           exitcode-stdio-1.0
  main-is:        NameOfYourTestSuite.hs
  hs-source-dirs: tests
  other-modules:
  build-depends:
    base,
    easytest
@

For tests that are logically separate, we usually combine them into a suite using 'tests', as in:

@
suite = tests
  [ scope "ex1" $ expect $ 1 + 1 == 2
  , scope "ex2" $ expect $ 2 + 2 == 4
  ]
@

We often want to generate random data for testing purposes:

@
reverseTest :: Test ()
reverseTest = scope "list reversal" $ propertyTest $ do
  nums <- 'forAll' $ Gen.list (Range.linear 0 100) (Gen.int (Range.linear 0 99))
  reverse (reverse nums) '===' nums
@

The above code generates lists of sizes between 0 and 100, consisting of @Int@ values in the range 0 through 99.

If our list reversal test failed, we might use @'runOnly' "list reversal"@ or @'rerunOnly' "list reversal" \<randomseed\>@ to rerun just that subtree of the test suite, and we might add some additional diagnostics to see what was going on:

@
import           EasyTest
import qualified Hedgehog.Gen   as Gen
import qualified Hedgehog.Range as Range

reverseTest :: Test ()
reverseTest = 'propertyTest' $ do
  nums <- 'forAll' $
    Gen.list (Range.linear 0 100) (Gen.int (Range.linear 0 99))
  'footnote' $ "nums: " ++ show nums
  let r = reverse (reverse nums)
  'footnote' $ "reverse (reverse nums): " ++ show r
  r '===' nums
@

-}

module EasyTest (
  -- * Tests
    Test
  -- * Structuring tests
  , tests
  , scope
  , unitTest
  , propertyTest
  -- * Running tests
  , run
  , runOnly
  , rerun
  , rerunOnly
  -- -- * Notes
  -- , note
  -- , noteShow
  -- * Assertions
  , expect
  , expectJust
  , expectRight
  , expectRightNoShow
  , expectLeft
  , expectLeftNoShow
  , expectEq
  , expectNeq
  , ok
  , skip
  , pending
  , crash
  -- * Hedgehog re-exports
  , (===)
  , (/==)
  , Seed
  , footnote
  , forAll
  , forAllWith
  ) where

import EasyTest.Internal
import Hedgehog          hiding (Test)
