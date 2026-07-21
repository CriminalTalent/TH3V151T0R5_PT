require 'net/http'
require 'json'
require 'uri'
require 'cgi'

class MastodonClient
  MAX_CHARS = 1000

  def initialize(base_url:, token:)
    @base_url = base_url.to_s.sub(%r{/\z}, '')
    @token    = token.to_s

    uri = URI(@base_url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = (uri.scheme == "https")
    @http.keep_alive_timeout = 30
  end

  def safe_utf8(str)
    return "" if str.nil?
    s = str.to_s.dup
    s.force_encoding('UTF-8')
    s.valid_encoding? ? s : s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '?')
  rescue
    str.to_s
  end

  def request(method:, path:, params: {}, form: nil, headers: {})
    uri = URI.join(@base_url, path)

    if method == :get && params && params.any?
      uri.query = URI.encode_www_form(params)
    end

    base_headers = { "Authorization" => "Bearer #{@token}" }.merge(headers || {})

    req =
      case method
      when :get
        Net::HTTP::Get.new(uri, base_headers)
      when :post
        r = Net::HTTP::Post.new(uri, base_headers)
        r.set_form_data(form) if form
        r
      else
        raise "Unsupported method: #{method}"
      end

    res = @http.request(req)
    body =
      begin
        JSON.parse(res.body)
      rescue
        {}
      end
    [res, body]
  rescue => e
    puts "[HTTP 오류] #{e.class} - #{e.message}"
    [nil, {}]
  end

  def mentions(since_id: nil)
    params = { limit: 20, exclude_types: [] }
    params[:since_id] = since_id.to_s if since_id && since_id.to_i > 0

    res, body = request(method: :get, path: "/api/v1/notifications", params: params)
    return [] unless res && res.code.to_i.between?(200, 299)
    
    notifications = body.is_a?(Array) ? body : []
    notifications.select { |n| n["type"] == "mention" }
  rescue => e
    puts "[mentions 오류] #{e.message}"
    []
  end

  def post_status(text, reply_to_id: nil, visibility: "unlisted")
    chunks = split_text(safe_utf8(text))
    last_res = nil
    current_reply_id = reply_to_id

    chunks.each do |chunk|
      form = { status: chunk, visibility: visibility }
      form[:in_reply_to_id] = current_reply_id if current_reply_id

      res, body = request(method: :post, path: "/api/v1/statuses", form: form)

      if body.is_a?(Hash) && body['id']
        current_reply_id = body['id']
      end

      last_res = res
      sleep 1 if chunks.size > 1
    end

    last_res
  rescue => e
    puts "[post_status 오류] #{e.message}"
  end

  def clean_content(notification)
    html = notification["status"]["content"]
    text = html.gsub(/<br\s*\/?>/i, "\n")
               .gsub(/<\/p>/i, "\n")
               .gsub(/<[^>]+>/, "")
    CGI.unescapeHTML(text).strip
  end

  private

  def split_text(text)
    return [text] if text.length <= MAX_CHARS

    chunks = []
    remaining = text.dup

    while remaining.length > MAX_CHARS
      slice = remaining[0, MAX_CHARS]
      cut = slice.rindex("\n") || MAX_CHARS
      chunks << remaining[0, cut].rstrip
      remaining = remaining[cut..].lstrip
    end

    chunks << remaining unless remaining.empty?
    chunks
  end
end
