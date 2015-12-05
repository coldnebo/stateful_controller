class InformationForm < Reform::Form 
  property :name, validates: {presence: true}
  property :favorite_day, validates: {presence: true}

  def persisted?; false; end
  def to_key; [1]; end
end

