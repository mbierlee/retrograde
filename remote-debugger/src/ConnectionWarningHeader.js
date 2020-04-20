import React from "react";
import "./ConnectionWarningHeader.module.css";
import Icon from "./Icon";

class ConnectionWarningHeader extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      elipsis: ".",
    };

    this.elipsisIntervalMs = 500;
  }

  componentDidMount() {
    this.interval = setInterval(() => {
      const elipsis = this.state.elipsis;
      const newElipsis = elipsis.length < 3 ? elipsis + "." : "";
      this.setState({ elipsis: newElipsis });
    }, this.elipsisIntervalMs);
  }

  componentWillUnmount() {
    clearInterval(this.interval);
  }

  render() {
    return (
      <div className="ConnectionWarningHeader">
        <Icon name="error_outline" />
        <p>Disconnected from engine. Reconnecting{this.state.elipsis}</p>
      </div>
    );
  }
}

export default ConnectionWarningHeader;
