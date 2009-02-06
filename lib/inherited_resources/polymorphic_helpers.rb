module InheritedResources #:nodoc:
  module PolymorphicHelpers #:nodoc:

    protected

      def parent_type
        @parent_type
      end

      def parent_class
        parent.class
      end

      def parent
        instance_variable_get("@#{@parent_type}")
      end

  end
end

