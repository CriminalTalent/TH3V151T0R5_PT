module ResultJudge
  def success_rate(stats:, stat1:, stat2:, difficulty:)
    s1 = stats[stat1].to_i
    s2 = stats[stat2].to_i
    luck = stats["행운"].to_i

    rate = 50 + ((s1 + s2) / 10).floor + (luck / 5).floor - difficulty.to_i
    [[rate, 20].max, 90].min
  end

  def judge(rate)
    roll = rand(1..100)

    if roll <= 5
      [:great_failure, roll]
    elsif roll <= rate
      if roll <= 10 || roll <= (rate * 0.15)
        [:great_success, roll]
      else
        [:success, roll]
      end
    else
      [:failure, roll]
    end
  end

  def reward_multiplier(result)
    {
      great_success: 1.5,
      success: 1.0,
      failure: 0.5,
      great_failure: 0.3
    }[result]
  end

  def result_label(result)
    {
      great_success: "대성공",
      success: "성공",
      failure: "실패",
      great_failure: "대실패"
    }[result]
  end
end
