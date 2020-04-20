import fetch from "cross-fetch";

import {
  CHECK_CONNECTION_DISCONNECTED,
  CHECK_CONNECTION_CONNECTED,
  CHECK_CONNECTION,
} from "./actionTypes";

export const checkConnection = (apiBaseUrl) => (dispatch, getState) => {
  const dispatchChangeConnectionState = (isConnectedNow) => {
    const wasConnected = getState().connection.isConnected;
    if (wasConnected != isConnectedNow) {
      isConnectedNow
        ? dispatch(checkConnectionConnected())
        : dispatch(checkConnectionDisconnected());
    }
  };

  dispatch({ type: CHECK_CONNECTION });
  fetch(apiBaseUrl + "/ping")
    .then(
      (response) => response.text(),
      () => dispatchChangeConnectionState(false)
    )
    .then((response) => {
      if (response === "pong") dispatchChangeConnectionState(true);
    });
};

export const checkConnectionConnected = () => ({
  type: CHECK_CONNECTION_CONNECTED,
});

export const checkConnectionDisconnected = () => ({
  type: CHECK_CONNECTION_DISCONNECTED,
});
