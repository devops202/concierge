import '@babel/polyfill';
import { of } from 'rxjs';
import AragonApi from '@aragon/api';

const INITIALIZATION_TRIGGER = Symbol('INITIALIZATION_TRIGGER');

const api = new AragonApi()

api.store(
  async (state, event) => {
    let newState

    switch (event.event) {
      case INITIALIZATION_TRIGGER:
        newState = { erc20: await getERC20() }
        break
      default:
        newState = state
    }

    return newState
  },
  [
    // Always initialize the store with our own home-made event
    of({ event: INITIALIZATION_TRIGGER }),
  ]
)

async function getERC20() {
  return await api.call('erc20').toPromise();
}
