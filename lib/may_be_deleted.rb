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
      association = self.class.find_association(association_name)
      if association 
        klass = association.class_name.constantize
        if klass.respond_to?("acts_as_paranoid")
          if self.class.singular_association?(association)
            id = self.send("#{association.primary_key_name}")
            klass.find_with_deleted(:first, :conditions => "id = #{id}") rescue nil
          else
            #will "#{association_name.singularize}_ids" work in all cases???
            ids = self.send("#{association_name.singularize}_ids")
            klass.find_with_deleted(:all, :conditions => "ids in (#{ids.join(",")})") rescue []
          end
        else
          self.send("#{association_name}")
        end
      else
        nil
      end
    end

  end


end

ActiveRecord::Base.send(:include, MayBeDeleted)
