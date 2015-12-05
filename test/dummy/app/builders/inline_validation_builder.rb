class InlineValidationBuilder < ActionView::Helpers::FormBuilder

  def error_for(field)
    @template.content_tag(:div, object.errors.messages[field].join, class: 'field_with_errors')
  end

end