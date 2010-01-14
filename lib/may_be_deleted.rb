module MayBeDeleted
  def self.included(base)
    base.extend ClassMethods
    base.class_eval do
      include InstanceMethods
    end
  end

  module ClassMethods
    def associations
      reflection_class = ActiveRecord::Reflection::AssociationReflection
      self.reflections.values.reject{|value| !value.instance_of?(reflection_class)}
    end

    def find_association(asso_name)
      self.associations.detect{|asso| asso.name.to_s.eql?(asso_name.to_s)}
    end

    ["belongs_to", "has_one", "has_many", "has_and_belongs_to_many"].each do |association_type|
      define_method "#{association_type}?" do |value|
        begin
          value.macro == association_type.intern
        rescue
          association = self.find_association(value)
          association && association.macro == association_type.intern
        end
      end
    end

    def singular_association?(name)
      self.belongs_to?(name) || self.has_one?(name)
    end
  end

  module InstanceMethods
    def force_find(association_name)
      associate = self.send("#{association_name}")
      association = self.class.find_association(association_name)
      if association 
        klass = association.class_name.constantize
        if klass.respond_to?("acts_as_paranoid")
          if self.class.singular_association?(association)
            if associate.nil? 
              key = association.primary_key_name
              if self.class.belongs_to?(association)
                polymorphic = association.options[:polymorphic]
                klass = self.send("#{association.options[:foreign_type]}").constantize if polymorphic
                id = self.send("#{key}")
                return klass.find_with_deleted(:first, :conditions => "id = #{id}") rescue nil
              else
                as = association.options[:as]
                if as
                  type_field = "#{as.to_s}_type"
                  return klass.find_with_deleted(:first, :conditions => "#{key} = #{self.id} and #{type_field} = '#{self.class.to_s}'") rescue nil
                else
                  return klass.find_with_deleted(:first, :conditions => "#{key} = #{self.id}") rescue nil
                end
              end
            end
          end
        end
      end
      return associate
    end
  end

end

ActiveRecord::Base.send(:include, MayBeDeleted)
