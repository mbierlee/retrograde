import fetch from "cross-fetch";

import {
  CHECK_CONNECTION_DISCONNECTED,
  CHECK_CONNECTION_CONNECTED,
} from "./actionTypes";

export const checkConnection = (apiBaseUrl) => (dispatch) => {
  fetch(apiBaseUrl + "/ping")
    .then(
      (response) => response.text(),
      () => dispatch(checkConnectionDisconnected())
    )
    .then((response) =>
      response === "pong" ? dispatch(checkConnectionConnected()) : response
    );
};

export const checkConnectionConnected = () => ({
  type: CHECK_CONNECTION_CONNECTED,
});

export const checkConnectionDisconnected = () => ({
  type: CHECK_CONNECTION_DISCONNECTED,
});
