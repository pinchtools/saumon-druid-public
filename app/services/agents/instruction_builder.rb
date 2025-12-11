class Agents::InstructionBuilder
  attr_reader :yaml

  def initialize(yaml)
    @yaml = yaml
  end

  def to_s
    [ role, directives, context_format ].compact.join("\n\n")
  end

  def role
    yaml["role"]
  end

  def directives
    yaml["directives"]
  end

  def context_format
    return nil unless yaml["context_format"]

    <<~TEXT
        CONTEXT_FORMAT
        ----------
        #{JSON.parse(yaml["context_format"])}
      TEXT
  end
end
