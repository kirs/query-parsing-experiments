require_relative './query_inspector.rb'

module QueryInspectorRelationHooks
  def load(*)
    QueryInspector.call(self)
    super
  end
end
ActiveRecord::Relation.prepend(QueryInspectorRelationHooks)
