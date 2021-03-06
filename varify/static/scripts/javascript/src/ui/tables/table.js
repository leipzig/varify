// Generated by CoffeeScript 1.7.1
var __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

define(['underscore', 'marionette', './body', './header'], function(_, Marionette, body, header) {
  var ResultTable;
  ResultTable = (function(_super) {
    __extends(ResultTable, _super);

    function ResultTable() {
      return ResultTable.__super__.constructor.apply(this, arguments);
    }

    ResultTable.prototype.tagName = 'table';

    ResultTable.prototype.className = 'table table-striped';

    ResultTable.prototype.itemView = body.ResultBody;

    ResultTable.prototype.itemViewOptions = function(item, index) {
      return _.defaults({
        collection: item.series
      }, this.options);
    };

    ResultTable.prototype.collectionEvents = {
      'change:currentpage': 'showCurentPage'
    };

    ResultTable.prototype.initialize = function() {
      this.data = {};
      if (!(this.data.view = this.options.view)) {
        throw new Error('view model required');
      }
      this.header = new header.Header({
        view: this.data.view
      });
      this.$el.append(this.header.render().el);
      return this.collection.on('reset', (function(_this) {
        return function() {
          if (_this.collection.objectCount === 0) {
            return _this.$el.hide();
          } else {
            _this.header.render();
            return _this.$el.show();
          }
        };
      })(this));
    };

    ResultTable.prototype.showCurentPage = function(model, num, options) {
      return this.children.each(function(view) {
        return view.$el.toggle(view.model.id === num);
      });
    };

    return ResultTable;

  })(Marionette.CollectionView);
  return {
    ResultTable: ResultTable
  };
});
