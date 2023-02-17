{-# LANGUAGE MultiParamTypeClasses, DeriveGeneric, RecordWildCards #-}

module Main where

import GHC.Generics               --base
import Control.Monad      (forM_) --base
--hasktorch 
import Torch.Tensor       (shape)
import Torch.Functional   (mseLoss)
import Torch.Device       (Device(..),DeviceType(..))
import Torch.NN           (Parameterized(..),Randomizable(..),sample)
import Torch.Optim        (GD(..))
--hasktorch-tools
import Torch.Train        (update)
import Torch.Tensor.TensorFactories (randnIO')
import Torch.Layer.LSTM   (LstmHypParams(..),InitialStatesHypParams(..),LstmParams(..),InitialStatesParams(..),lstmLayers,toDependentTensors)

data HypParams = HypParams {
    dev :: Device,
    inputDim :: Int,
    hiddenDim :: Int,
    isBiLstm ::  Bool,
    numOfLayers :: Int,
    dropout :: Maybe Double,
    projDim :: Maybe Int
    } deriving (Eq, Show)

data Params = Params {
  iParams :: InitialStatesParams,
  lParams :: LstmParams
  } deriving (Show, Generic)
instance Parameterized Params

instance Randomizable HypParams Params where
  sample HypParams{..} = Params
      <$> (sample $ InitialStatesHypParams dev isBiLstm hiddenDim numOfLayers)
      <*> (sample $ LstmHypParams dev isBiLstm inputDim hiddenDim numOfLayers True projDim)

-- | Test code to check the shapes of output tensors for the cases of
-- |   bidirectional True/False | numOfLayers 1,2,3 | dropout on/off | projDim on/off
main :: IO()
main = do
  let dev = Device CUDA 0
      iDim = 2
      hDim = 4
      isBiLstm = True
      numOfLayers = 3
      dropout = Just 0.5
      projDim = Just 3
      seqLen = 10
      hypParams = HypParams dev iDim hDim isBiLstm numOfLayers dropout projDim
      d = if isBiLstm then 2 else 1
      oDim = case projDim of
               Just projD -> projD
               Nothing -> hDim
  initialParams <- sample hypParams
  inputs <- randnIO' dev [seqLen,iDim]
  gt     <- randnIO' dev [seqLen,oDim]
  let lstmOut = fst $ lstmLayers (lParams initialParams) (toDependentTensors $ iParams initialParams) dropout inputs
      loss = mseLoss lstmOut gt
  (u,_) <- update initialParams GD loss 5e-1
  print u
