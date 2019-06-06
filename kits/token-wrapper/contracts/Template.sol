/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 *
 * This file requires contract dependencies which are licensed as
 * GPL-3.0-or-later, forcing it to also be licensed as such.
 *
 * This is the only file in your project that requires this license and
 * you are free to choose a different license for the rest of the project.
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/factory/DAOFactory.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";
import "@aragon/os/contracts/apm/APMNamehash.sol";

import "@aragon/apps-voting/contracts/Voting.sol";
// import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";
import "@aragon/apps-vault/contracts/Vault.sol";
import "@aragon/apps-finance/contracts/Finance.sol";

// import "./CounterApp.sol";
import "./TokenWrapper.sol";

// TODO: Remove
import "./test/mocks/ERC20Sample.sol";

contract TemplateBase is APMNamehash {
    ENS public ens;
    DAOFactory public fac;

    event DeployInstance(address dao);
    event InstalledApp(address appProxy, bytes32 appId);

    constructor(DAOFactory _fac, ENS _ens) public {
        ens = _ens;

        // If no factory is passed, get it from on-chain bare-kit
        if (address(_fac) == address(0)) {
            bytes32 bareKit = apmNamehash("bare-kit");
            fac = TemplateBase(latestVersionAppBase(bareKit)).fac();
        } else {
            fac = _fac;
        }
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }
}


contract Template is TemplateBase {
  MiniMeTokenFactory tokenFactory;

  uint64 constant PCT = 10 ** 16;
  address constant ANY_ENTITY = address(-1);

  constructor(ENS ens) TemplateBase(DAOFactory(0), ens) public {
    tokenFactory = new MiniMeTokenFactory();
  }

  function createApp(Kernel dao, bytes32 id) internal returns(address) {
    return dao.newAppInstance(id, latestVersionAppBase(id));
  }

  function newInstance() public {
    
    // Initialize DAO.
    address root = msg.sender;
    Kernel dao = fac.newDAO(this);
    ACL acl = ACL(dao.acl());
    acl.createPermission(this, dao, dao.APP_MANAGER_ROLE(), this);

    // Create apps.
    // CounterApp app = CounterApp(createApp(dao, apmNamehash("react-test")));
    Voting voting = Voting(createApp(dao, apmNamehash("voting")));
    // TokenManager tokenManager = TokenManager(createApp(dao, apmNamehash("token-manager")));
    Vault vault = Vault(createApp(dao, apmNamehash("vault")));
    Finance finance = Finance(createApp(dao, apmNamehash("finance")));
    TokenWrapper tokenWrapper = TokenWrapper(createApp(dao, apmNamehash("token-wrapper")));

    // Create MiniMe token.
    MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, "App token", 0, "APP", true);
    token.changeController(tokenWrapper);

    // Create a dummy token.
    // TODO: Remove - Users should be able to set this dynamically...
    ERC20Sample wrappedToken = new ERC20Sample();

    // Initialize apps.
    // app.initialize();
    // tokenManager.initialize(token, true, 0);
    voting.initialize(token, 50 * PCT, 20 * PCT, 1 days);
    vault.initialize();
    finance.initialize(vault, 30 days);
    tokenWrapper.initialize(token, wrappedToken);

    // Mint one token to the sender.
    // acl.createPermission(this, tokenManager, tokenManager.MINT_ROLE(), this);
    // tokenManager.mint(root, 1); // Give one token to root

    // Allow any entity to create a vote.
    acl.createPermission(ANY_ENTITY, voting, voting.CREATE_VOTES_ROLE(), root);

    // Allow the voting app to increment the counter, and any entity to decrement it.
    // acl.createPermission(voting, app, app.INCREMENT_ROLE(), voting);
    // acl.createPermission(ANY_ENTITY, app, app.DECREMENT_ROLE(), root);

    // Allow the token manager to mint tokens.
    // acl.grantPermission(voting, tokenManager, tokenManager.MINT_ROLE());

    // Setup permissions for the finance and vault apps.
    acl.createPermission(finance, vault, vault.TRANSFER_ROLE(), voting);
    acl.createPermission(voting, finance, finance.CREATE_PAYMENTS_ROLE(), voting);
    acl.createPermission(voting, finance, finance.EXECUTE_PAYMENTS_ROLE(), voting);
    acl.createPermission(voting, finance, finance.MANAGE_PAYMENTS_ROLE(), voting);

    // TODO: Set permissions for the token wrapper app.
    // ...

    // Clean up permissions.
    acl.grantPermission(root, dao, dao.APP_MANAGER_ROLE());
    acl.revokePermission(this, dao, dao.APP_MANAGER_ROLE());
    acl.setPermissionManager(root, dao, dao.APP_MANAGER_ROLE());
    acl.grantPermission(root, acl, acl.CREATE_PERMISSIONS_ROLE());
    acl.revokePermission(this, acl, acl.CREATE_PERMISSIONS_ROLE());
    acl.setPermissionManager(root, acl, acl.CREATE_PERMISSIONS_ROLE());

    emit DeployInstance(dao);
  }
}
