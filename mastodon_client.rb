require "net/http"
require "json"
require "uri"
require "cgi"

class MastodonClient
  def initialize(base_url:, token:)
    @base_url = base_url
    @token    = token
  end

  # 멘션 알림 조회. since_id 이후의 mention 타입만 반환.
  def mentions(since_id: nil)
    uri = URI("#{@base_url}/api/v1/notifications")
    params = { "types[]" => "mention", "limit" => "20" }
    params["since_id"] = since_id if since_id && !since_id.to_s.empty?
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@token}"

    res = http.request(req)
    return [] unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  rescue => e
    puts "[mentions 오류] #{e.message}"
    []
  end

  def post_status(text, reply_to_id: nil, visibility: "unlisted")
    uri = URI("#{@base_url}/api/v1/statuses")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@token}"
    req["Content-Type"]  = "application/json"
    body = { status: text, visibility: visibility }
    body[:in_reply_to_id] = reply_to_id if reply_to_id
    req.body = body.to_json

    res = http.request(req)
    data = JSON.parse(res.body)
    data["id"]
  rescue => e
    puts "[post_status 오류] #{e.message}"
    nil
  end

  # 알림 객체(해시)에서 본문 텍스트 추출
  def clean_content(notification)
    html = notification.dig("status", "content").to_s
    text = html.gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/p>/i, "\n")
               .gsub(/<[^>]+>/, "")
    CGI.unescapeHTML(text).strip
  end
end
