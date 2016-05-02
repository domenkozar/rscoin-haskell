{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}

module Context 
    ( BankInfo(..)
    , MintetteInfo(..)
    , TestContext(..)
    , TestEnv
    , mkTestContext
    , bank, mintettes, buser, users, lifetime
    , keys, secretKey, publicKey
    , state
    , port
    ) where

import           Control.Lens         (Getter, makeLenses, _1, _2, to)
import           Control.Monad        (replicateM, forM)
import           Control.Monad.Trans  (MonadIO, liftIO)
import           Control.Monad.Reader (ReaderT)

import qualified RSCoin.Bank       as B
import qualified RSCoin.Mintette   as M
import qualified RSCoin.User       as U
import           RSCoin.Core          (SecretKey, PublicKey, keyGen, bankPort)
import           RSCoin.Test          (MicroSeconds)

data BankInfo = BankInfo
    { _bankKeys  :: (SecretKey, PublicKey)
    , _bankState :: B.State
    }
$(makeLenses ''BankInfo)

data MintetteInfo = MintetteInfo
    { _mintetteKeys  :: (SecretKey, PublicKey)
    , _mintetteState :: M.State
    , _mintettePort  :: Int
    }
$(makeLenses ''MintetteInfo)

data UserInfo = UserInfo
    { _userKeys  :: (SecretKey, PublicKey)
    , _userState :: U.RSCoinUserState
    }
$(makeLenses ''UserInfo)

data TestContext = TestContext
    { _bank      :: BankInfo
    , _mintettes :: [MintetteInfo]
    , _buser     :: UserInfo  -- ^ user in bank mode
    , _users     :: [UserInfo]
    , _lifetime  :: MicroSeconds
    }
$(makeLenses ''TestContext)

type TestEnv m a = ReaderT TestContext m a

mkTestContext :: MonadIO m => Int -> Int -> MicroSeconds -> m TestContext
mkTestContext mNum uNum lt = liftIO $ do 
    TestContext <$> binfo <*> minfos <*> buinfo <*> uinfos <*> pure lt
  where
    binfo  = BankInfo <$> keyGen <*> B.openMemState
    minfos = forM [0 .. mNum - 1] $ \mid ->
             MintetteInfo <$> keyGen <*> M.openMemState <*> pure (2300 + mid)
    buinfo = UserInfo <$> keyGen <*> U.openMemState
    uinfos = replicateM mNum $  
             UserInfo <$> keyGen <*> U.openMemState


-- * Shortcuts

class WithKeys w where
    keys :: Getter w (SecretKey, PublicKey)

secretKey :: WithKeys w => Getter w SecretKey
secretKey = keys . _1

publicKey :: WithKeys w => Getter w PublicKey
publicKey = keys . _2

instance WithKeys BankInfo where
    keys = bankKeys

instance WithKeys MintetteInfo where
    keys = mintetteKeys

instance WithKeys UserInfo where
    keys = userKeys


class WithState w s | w -> s where
    state :: Getter w s 

instance WithState BankInfo B.State where
    state = bankState

instance WithState MintetteInfo M.State where
    state = mintetteState

instance WithState UserInfo U.RSCoinUserState where
    state = userState


class WithPort w where
    port :: Getter w Int

instance WithPort BankInfo where
    port = to $ const bankPort

instance WithPort MintetteInfo where
    port = mintettePort
