import {
  CHECK_CONNECTION_CONNECTED,
  CHECK_CONNECTION_DISCONNECTED,
} from "./actionTypes";
import { combineReducers } from "redux";

function changeState(state, stateDiff) {
  const newState = JSON.parse(JSON.stringify(state));
  Object.assign(newState, stateDiff);
  return newState;
}

function connection(state = { isConnected: false }, action) {
  switch (action.type) {
    case CHECK_CONNECTION_CONNECTED:
      return changeState(state, {
        isConnected: true,
      });
    case CHECK_CONNECTION_DISCONNECTED:
      return changeState(state, {
        isConnected: false,
      });
    default:
      return state;
  }
}

const rootReducer = combineReducers({ connection });

export default rootReducer;
