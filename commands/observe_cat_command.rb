class ObserveCatCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[관찰]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    cat = @sheet.cat(account)
    dominant = dominant_trait(cat)

    text =
      case dominant
      when :affection
        "카피캣은 당신이 웃기 전부터 웃는 법을 준비하고 있었습니다."
      when :aggression
        "카피캣은 소리 없이 엎드렸습니다. 장난감이 아니라 사냥감을 기다리는 자세입니다."
      when :stability
        "카피캣은 조용합니다. 이상할 만큼, 이 방에서 가장 안정된 생물처럼 보입니다."
      when :weirdness
        "카피캣의 그림자가 아주 조금 늦게 움직입니다."
      when :unknown
        "카피캣은 당신을 보지 않았습니다. 당신 뒤에 있는, 아직 오지 않은 무언가를 보고 있었습니다."
      else
        "카피캣은 아직 작고 따뜻합니다. 다만 당신의 눈 깜빡임을 놓치지 않습니다."
      end

    @sheet.log(account, "관찰", dominant.to_s)

    text
  end

  private

  def dominant_trait(cat)
    values = {
      affection: cat[:affection],
      aggression: cat[:aggression],
      stability: cat[:stability],
      weirdness: cat[:weirdness],
      unknown: cat[:unknown]
    }

    return nil if values.values.all?(&:zero?)

    values.max_by { |_k, v| v }[0]
  end
end
