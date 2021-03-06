{-# LANGUAGE GADTs           #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ViewPatterns    #-}
-- |
-- Module      : Data.Array.Accelerate.Numeric.Sum.LLVM.Prim
-- Copyright   : [2017] Trevor L. McDonell
-- License     : BSD3
--
-- Maintainer  : Trevor L. McDonell <tmcdonell@cse.unsw.edu.au>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Data.Array.Accelerate.Numeric.Sum.LLVM.Prim (

  fadd, fsub, fmul,

) where

import Data.Array.Accelerate.Type
import Data.Array.Accelerate.Error

import Data.Array.Accelerate.LLVM.CodeGen.Downcast                  ( downcast )
import Data.Array.Accelerate.LLVM.CodeGen.IR                        ( IR(..), Operands(..), IROP(..) )
import Data.Array.Accelerate.LLVM.CodeGen.Monad                     ( CodeGen, freshName, instr_ )
import Data.Array.Accelerate.LLVM.CodeGen.Sugar                     ( IROpenFun1(..) )
import qualified Data.Array.Accelerate.LLVM.CodeGen.Arithmetic      as A
import qualified LLVM.AST.Type.Name                                 as A
import qualified LLVM.AST.Type.Operand                              as A
import qualified LLVM.AST.Type.Representation                       as A

import LLVM.AST.Instruction
import LLVM.AST.Name
import LLVM.AST.Operand
import LLVM.AST.Type


-- | As (+), but don't allow potentially unsafe floating-point optimisations.
--
fadd :: FloatingType a -> IROpenFun1 arch env aenv ((a,a) -> a)
fadd t = IRFun1 $ A.uncurry (binop FAdd t)

-- | As (-), but don't allow potentially unsafe floating-point optimisations.
--
fsub :: FloatingType a -> IROpenFun1 arch env aenv ((a,a) -> a)
fsub t = IRFun1 $ A.uncurry (binop FSub t)

-- | As (*), but don't allow potentially unsafe floating-point optimisations.
--
fmul :: FloatingType a -> IROpenFun1 arch env aenv ((a,a) -> a)
fmul t = IRFun1 $ A.uncurry (binop FMul t)

binop :: (FastMathFlags -> Operand -> Operand -> InstructionMetadata -> Instruction) -> FloatingType a -> IR a -> IR a -> CodeGen (IR a)
binop f t (op t -> x) (op t -> y) = do
  r <- instr (downcast t) (f fmf (downcast x) (downcast y) md)
  return (upcast t r)


-- Prim
-- ----

md :: InstructionMetadata
md = []

fmf :: FastMathFlags
fmf = NoFastMathFlags

fresh :: CodeGen Name
fresh = downcast <$> freshName

instr :: Type -> Instruction -> CodeGen Operand
instr ty ins = do
  name <- fresh
  instr_ (name := ins)
  return (LocalReference ty name)

upcast :: FloatingType t -> Operand -> IR t
upcast TypeFloat{}   (LocalReference (FloatingPointType FloatFP)  (UnName x)) = IR $ OP_Float   (A.LocalReference A.type' (A.UnName x))
upcast TypeDouble{}  (LocalReference (FloatingPointType DoubleFP) (UnName x)) = IR $ OP_Double  (A.LocalReference A.type' (A.UnName x))
upcast TypeCFloat{}  (LocalReference (FloatingPointType FloatFP)  (UnName x)) = IR $ OP_CFloat  (A.LocalReference A.type' (A.UnName x))
upcast TypeCDouble{} (LocalReference (FloatingPointType DoubleFP) (UnName x)) = IR $ OP_CDouble (A.LocalReference A.type' (A.UnName x))
upcast _ _ = $internalError "upcast" "expected local reference"

