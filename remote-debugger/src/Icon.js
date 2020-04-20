import React from "react";
import PropTypes from "prop-types";

import "material-design-icons/iconfont/material-icons.css";

const Icon = ({ name }) => <span className="Icon material-icons">{name}</span>;

Icon.propTypes = {
  name: PropTypes.string.isRequired,
};

export default Icon;
