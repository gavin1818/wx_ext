# encoding: UTF-8

require 'nokogiri'
require 'rest_client'
require 'json'
require 'open-uri'

module WxExt
  #  微信扩展接口, 从搜狗微信抓取微信文章
  # @author FuShengYang
  class SougouWeixin
    def self.spider_posts_from_sougou(openid, page_index = 1, date_last = (Time.now - 3600 * 24 * 10).strftime("%Y-%m-%d"))
      json_url = "http://weixin.sogou.com/gzhjs?&openid=#{openid}&page=#{page_index}"
      res = RestClient.get json_url

      date_last_arr = date_last.to_s.split('-')
      date_last_to_com = Time.new(date_last_arr[0], date_last_arr[1], date_last_arr[2])

      xml_articles = nil
      response_time = nil
      total_items = nil
      total_pages = nil
      page = nil

      reg = /gzh\((.*)\).*\/\/<\!--.*--><\!--(\d+)-->/m
      if reg =~ res.to_s
        xml_articles = JSON.parse($1)['items']
        total_items = JSON.parse($1)['totalItems']
        total_pages = JSON.parse($1)['totalPages']
        page = JSON.parse($1)['page']
        response_time = $2.to_i
      else
        return {}
      end
      spider_posts = []
      xml_articles.each do |xml|
        doc = Nokogiri::XML(xml, nil, 'UTF-8')
        date = doc.at_xpath('//DOCUMENT/item/display/date').text
        spider_post = {}

        date_arr = date.to_s.split('-')
        date_to_com = Time.new(date_arr[0], date_arr[1], date_arr[2])
        if date_last_to_com < date_to_com
          title = doc.at_xpath('//DOCUMENT/item/display/title1').text
          url = doc.at_xpath('//DOCUMENT/item/display/url').text
          img = doc.at_xpath('//DOCUMENT/item/display/imglink').text
          content_short = doc.at_xpath('//DOCUMENT/item/display/content168').text

          doc_post = Nokogiri::HTML(open(url), nil, 'UTF-8')
          node_author = doc_post.css('div.rich_media_meta_list > em.rich_media_meta.rich_media_meta_text')[1]
          author = node_author ? node_author.content : '无'
          content = doc_post.css('div#js_content').first.to_s
          spider_post = {
            title: title,
            url: url,
            img: img,
            content_short: content_short,
            author: author,
            content: content,
            date: date
          }
          spider_posts.push spider_post
        else
          break
        end
      end
      {
        total_items: total_items,
        total_pages: total_pages,
        page: page,
        response_time: response_time,
        spider_posts: spider_posts,
        original_count: xml_articles.count,
        count: spider_posts.count
      }
    end

    def self.spider_posts_later_date(openid, date_last = (Time.now - 3600 * 24 * 10).strftime("%Y-%m-%d"))
      spider_posts_first_page_hash = spider_posts_from_sougou(openid, 1, date_last)
      total_pages = spider_posts_first_page_hash[:total_pages].to_i
      spider_posts = []
      1.upto(total_pages).each do |page_index|
        spider_posts_hash = spider_posts_from_sougou(openid, page_index, date_last)
        if spider_posts_hash[:original_count] == spider_posts_hash[:count]
          spider_posts += spider_posts_hash[:spider_posts]
        else
          break
        end
      end
      {
          total_items: spider_posts_first_page_hash[:total_items],
          total_pages: total_pages,
          spider_posts: spider_posts.uniq
      }
    end
  end
end