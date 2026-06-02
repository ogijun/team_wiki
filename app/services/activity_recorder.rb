module ActivityRecorder
  module_function

  def record(actor:, action:, subject: nil, subject_label: nil)
    Activity.create!(
      user: actor,
      action: action,
      subject: subject,
      subject_label: subject_label || default_label(subject)
    )
  end

  def default_label(subject)
    return nil if subject.nil?
    return subject.title         if subject.respond_to?(:title)
    return subject.display_title if subject.respond_to?(:display_title)
    return subject.name          if subject.respond_to?(:name)
    nil
  end
end
