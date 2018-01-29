module QueryInspector
  extend self
  attr_accessor :logger

  def call(relation)
    unless logger
      raise ArgumentError, "QueryInspector.logger must be set"
    end

    where_columns = referenced_columns(relation)
    order_columns = columns_from_order(relation)

    indexes = relation_indexes(relation)
    columns = where_columns + order_columns
    logger.info "#{relation.to_sql} => #{columns.to_a}" if columns.any?

    columns_hit_index = columns.count { |col| indexes.any? { |index| index_matches_column?(index, col) } }

    # match ORDER BY shop_id, created_at with shop_id_and_created_at index
    # match WHERE shop_id, created_at with shop_id_and_created_at index
    #
    # More examples: https://github.com/Shopify/appscale-team/issues/12
    # first basic rule: hit at least one index
  end

  def relation_indexes(relation)
    relation.model.connection.indexes(relation.table_name)
  end

  def index_matches_column?(index, column)
    index.columns.first == column.split(".").last
  end

  def columns_from_order(relation)
    columns = [].to_set
    relation.order_values.each do |node|
      case node
      when String
        cols = node.split(",").map(&:strip)
        cols.each do |col|
          if match = col.match(/^(\S+)(\w(desc|DESC|asc|ASC))?/)
            columns << column_with_table_name(match[1], relation.table_name)
          else
            logger.warn "Failed to parse #{node.inspect}"
          end
        end
      when Arel::Nodes::Ascending, Arel::Nodes::Descending
        node.value.name
      else
        logger.warn "Unknown node: #{node.class}"
      end
    end
    columns
  end

  def referenced_columns(relation)
    columns_used = [].to_set

    relation.where_clause.send(:predicates).each do |node|
      case node
      when String
        case node
        when "1=0"
          # fake query, no-op
          return [].to_set
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
    columns_used
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
