module QueryInspector
  extend self
  attr_accessor :logger

  def call(relation)
    unless logger
      raise ArgumentError, "logger must be set"
    end

    columns_used = [].to_set
    relation.where_clause.send(:predicates).each do |node|
      case node
      when String
        case node
        when "1=0"
          # fake query, no-op
          return
        when (/^(\S+) (IS|is|like|LIKE|=|>|<|>=|<=|!=)/)
          columns_used << column_with_table_name($1, relation.table_name)
        else
          logger.warn "Failed to parse #{node.inspect}"
        end
      when Arel::Nodes::Between
        attribute = node.left
        column = "#{attribute.relation.name}.#{attribute.name}"
        columns_used << column
      when Arel::Nodes::Equality, Arel::Nodes::NotEqual,
           Arel::Nodes::GreaterThanOrEqual, Arel::Nodes::LessThanOrEqual,
           Arel::Nodes::GreaterThan, Arel::Nodes::LessThan,
           Arel::Nodes::NotIn
        column = node.left
        columns_used << "#{column.relation.name}.#{column.name}"
      when Arel::Nodes::Grouping
        # skip it because it already sucks in terms of indexes
      else
        logger.warn "Unknown node: #{node.class}"
      end
    end
    logger.info "#{relation.to_sql} => #{columns_used.to_a}" if columns_used.any?
  end

  def column_with_table_name(column, table_name)
    column = column.gsub("`", "")
    if column.include?(".")
      column
    else
      "#{table_name}.#{column}"
    end
  end
end
