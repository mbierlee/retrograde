import { createStore, compose, applyMiddleware } from "redux";
import thunk from "redux-thunk";
import appReducer from "./reducers";

const enhancer = compose(
  applyMiddleware(thunk),
  window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
);

const store = createStore(appReducer, enhancer);

export default store;
