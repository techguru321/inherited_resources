module InheritedResources #:nodoc:
  module BelongsToHelpers #:nodoc:

    # Private helpers, you probably don't have to worry with them.
    private

      def parent?
        true
      end

      # Evaluate the parent given. This is used to nest parents in the
      # association chain.
      #
      def evaluate_parent(parent_config, chain = nil)
        instantiated_object = instance_variable_get("@#{parent_config[:instance_name]}")
        return instantiated_object if instantiated_object

        scoped_parent = if chain
          chain.send(parent_config[:collection_name])
        else
          parent_config[:parent_class]
        end

        scoped_parent = scoped_parent.send(parent_config[:finder], params[parent_config[:param]])

        instance_variable_set("@#{parent_config[:instance_name]}", scoped_parent)
      end

      # Overwrites the end_of_association_chain method.
      #
      # This methods gets your begin_of_association_chain, join it with your
      # parents chain and returns the scoped association.
      #
      def end_of_association_chain
        chain = symbols_for_chain.inject(begin_of_association_chain) do |chain, symbol|
          evaluate_parent(resources_configuration[symbol], chain)
        end

        return resource_class unless chain

        chain = chain.send(method_for_association_chain) if method_for_association_chain
        return chain
      end

      # If current controller is singleton, returns instance name to
      # end_of_association_chain. This means that we will have the following
      # chain:
      #
      #   Project.find(params[:project_id]).manager
      #
      # Instead of:
      #
      #   Project.find(params[:project_id]).managers
      #
      def method_for_association_chain
        singleton ? nil : resource_collection_name
      end

      # Maps parents_symbols to build association chain. In this case, it
      # simply return the parent_symbols, however on polymorphic belongs to,
      # it has some customization to deal with properly.
      #
      def symbols_for_chain
        parents_symbols
      end

  end
end
