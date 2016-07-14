require 'nokogiri'

module XML
  class Parser
    def initialize(node, &block)
      @node = node
      @node.each do
        self.instance_eval &block
      end
    end

    def method_missing(sym, *args, &block)
      @node.send sym, *args, &block
    end

    def is_start?
      @node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    end

    def is_end?
      @node.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT
    end

    def for_element(name, &block)
      return unless self.name == name and is_start?
      self.instance_eval &block
    end

    def inside_element(name=nil, &block)
      return if @node.self_closing?
      return unless name.nil? or (self.name == name and is_start?)

      name = @node.name
      depth = @node.depth

      @node.each do
        return if self.name == name and is_end? and @node.depth == depth
        self.instance_eval &block
      end
    end
  end
end
