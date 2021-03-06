// Generated by CoffeeScript 1.7.1
var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

define(['underscore', 'cilantro'], function(_, c) {
  var HgmdSelector;
  HgmdSelector = (function(_super) {
    __extends(HgmdSelector, _super);

    function HgmdSelector() {
      return HgmdSelector.__super__.constructor.apply(this, arguments);
    }

    HgmdSelector.prototype.template = 'varify/controls/hgmd';

    HgmdSelector.prototype.ui = {
      select: '.hgmd-selector'
    };

    HgmdSelector.prototype.events = {
      'change .hgmd-selector': 'change'
    };

    HgmdSelector.prototype.initialize = function() {
      return this.on('ready', function() {
        return this.change();
      });
    };

    HgmdSelector.prototype.getOperator = function() {
      return "isnull";
    };

    HgmdSelector.prototype.getValue = function() {
      return this.ui.select.val() === "true";
    };

    HgmdSelector.prototype.setValue = function(value) {
      return this.ui.select.val(value.toString());
    };

    return HgmdSelector;

  })(c.ui.ControlItemView);
  return {
    HgmdSelector: HgmdSelector
  };
});
