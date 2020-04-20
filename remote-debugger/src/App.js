import React from "react";
import "./App.module.css";
import ConnectionWarningHeader from "./ConnectionWarningHeader";
import { checkConnection } from "./redux/actions";
import { connect } from "react-redux";

class App extends React.Component {
  render() {
    return (
      <div className="App">
        <header>
          <h1>Retrograde Remote Debugger</h1>
          {!this.props.isConnected && <ConnectionWarningHeader />}
        </header>
      </div>
    );
  }

  componentDidMount() {
    const apiBaseUrl = "http://localhost:8080";
    const connectionCheckIntervalMs = 1000;
    const checkConnection = () => this.props.onCheckConnection(apiBaseUrl);
    checkConnection();
    this.connectionCheckIntervalHandle = setInterval(
      () => checkConnection(),
      connectionCheckIntervalMs
    );
  }

  componentWillUnmount() {
    clearInterval(this.connectionCheckIntervalHandle);
  }
}

const mapStateToProps = (state) => {
  return {
    isConnected: state.connection.isConnected,
  };
};

const mapDispatchToProps = (dispatch) => ({
  onCheckConnection: (apiBaseUrl) => dispatch(checkConnection(apiBaseUrl)),
});

export default connect(mapStateToProps, mapDispatchToProps)(App);
