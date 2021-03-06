// Generated by CoffeeScript 1.7.1
var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

define(['underscore', 'cilantro'], function(_, c) {
  var PolyPhenSelector;
  PolyPhenSelector = (function(_super) {
    __extends(PolyPhenSelector, _super);

    function PolyPhenSelector() {
      return PolyPhenSelector.__super__.constructor.apply(this, arguments);
    }

    PolyPhenSelector.prototype.template = 'varify/controls/polyphen';

    PolyPhenSelector.prototype.ui = {
      select: '.polyphen-selector'
    };

    PolyPhenSelector.prototype.events = {
      'change .polyphen-selector': 'change'
    };

    PolyPhenSelector.prototype.initialize = function() {
      return this.on('ready', function() {
        return this.change();
      });
    };

    PolyPhenSelector.prototype.getOperator = function() {
      if (this.ui.select.val() === 'benign') {
        return 'lte';
      } else if (this.ui.select.val() === 'possibly-damaging') {
        return 'range';
      } else {
        return 'gte';
      }
    };

    PolyPhenSelector.prototype.getValue = function() {
      if (this.ui.select.val() === 'benign') {
        return 0.2;
      } else if (this.ui.select.val() === 'possibly-damaging') {
        return [0.2, 0.85];
      } else {
        return 0.85;
      }
    };

    PolyPhenSelector.prototype.setOperator = function(operator) {
      if (operator === 'lte') {
        return this.ui.select.val('benign');
      } else if (operator === 'range') {
        return this.ui.select.val('possibly-damaging');
      } else {
        return this.ui.select.val('probably-damaging');
      }
    };

    return PolyPhenSelector;

  })(c.ui.ControlItemView);
  return {
    PolyPhenSelector: PolyPhenSelector
  };
});
