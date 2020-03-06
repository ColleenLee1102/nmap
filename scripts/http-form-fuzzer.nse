description = [[
Performs a simple form fuzzing against forms found on websites.
Tries strings and numbers of increasing length and attempts to
determine if the fuzzing was successful.
]]

---
-- @usage
-- nmap --script http-form-fuzzer --script-args 'http-form-fuzzer.targets={1={path=/},2={path=/register.html}}' -p 80 <host>
--
-- This script attempts to fuzz fields in forms it detects (it fuzzes one field at a time).
-- In each iteration it first tries to fuzz a field with a string, then with a number.
-- In the output, actions and paths for which errors were observed are listed, along with
-- names of fields that were being fuzzed during error occurrence. Length and type
-- (string/integer) of the input that caused the error are also provided.
-- We consider an error to be either: a response with status 500 or with an empty body,
-- a response that contains "server error" or "sql error" strings. ATM anything other than
-- that is considered not to be an 'error'.
-- TODO: develop more sophisticated techniques that will let us determine if the fuzzing was
-- successful (i.e. we got an 'error'). Ideally, an algorithm that will tell us a percentage
-- difference between responses should be implemented.
--
-- @output
-- PORT   STATE SERVICE REASON
-- 80/tcp open  http    syn-ack
-- | http-form-fuzzer:
-- |   Path: /register.html Action: /validate.php
-- |     age
-- |       integer lengths that caused errors:
-- |         10000, 10001
-- |     name
-- |       string lengths that caused errors:
-- |         40000
-- |   Path: /form.html Action: /check_form.php
-- |     fieldfoo
-- |       integer lengths that caused errors:
-- |_        1, 2
--
-- @args http-form-fuzzer.targets a table with the targets of fuzzing, for example
-- {{path = /index.html, minlength = 40002}, {path = /foo.html, maxlength = 10000}}.
-- The path parameter is required, if minlength or maxlength is not specified,
-- then the values of http-form-fuzzer.minlength or http-form-fuzzer.maxlength will be used.
-- Defaults to {{path="/"}}
-- @args http-form-fuzzer.minlength the minimum length of a string that will be used for fuzzing,
-- defaults to 300000
-- @args http-form-fuzzer.maxlength the maximum length of a string that will be used for fuzzing,
-- defaults to 310000
--

author = {"Piotr Olma", "Gioacchino Mazzurco"}
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"fuzzer", "intrusive"}

local shortport = require 'shortport'
local http = require 'http'
local httpspider = require 'httpspider'
local stdnse = require 'stdnse'
local string = require 'string'
local table = require 'table'
local url = require 'url'
local rand = require 'rand'
--zl3
local crete = require "crete"

--zl3 lua cov
local luacov = require "luacov.runner"
--zl3 lua cov

--zl3 start collect luacov data
--luacov.init()
print("after luacov init count ")
--zl3 end

-- generate a charset that will be used for fuzzing
local function generate_charset(left_bound, right_bound, ...)
  local t = ... or {}
  if left_bound > right_bound then
    return t
  end
  for i=left_bound,right_bound do
    table.insert(t, string.char(i))
  end
  return t
end

-- check if the response we got indicates that fuzzing was successful
local function check_response(response)
  --zl3
  print("make concolic1")
  --print(response_string.body)
  --print(type(response_string.body))
  print("before sendpid!")
  --zl3 for replay sendpid has to be commented out
  --crete.sendpid()
  --crete.mconcolic(response.body,12)
  
  --for zl3 replay test cases
  local test_table = crete.replaytest("/home/zheli/clean_crete/text-test-case/1.txt")
  --local test_table = crete.replaytest("/home/zheli/clean_crete/content_server_error.txt")
  
  for k, v in pairs(test_table) do
     print(k, v)
     response.body = v
     if not(response.body) or response.status==500 then
        return true
     end
     --if response.body:find("[Ss][Ee][Rr][Vv][Ee][Rr]%s*[Ee][Rr][Rr][Oo][Rr]") or response.body:find("[Ss][Qq][Ll]%s*[Ee][Rr][Rr][Oo][Rr]") then
     if response.body:find("SERVER ERROR") then
        print("hit")
        --return true
     end
  end
  
  --if not(response.body) or response.status==500 then
    --return true
  --end
  --if response.body:find("[Ss][Ee][Rr][Vv][Ee][Rr]%s*[Ee][Rr][Rr][Oo][Rr]") or response.body:find("[Ss][Qq][Ll]%s*[Ee][Rr][Rr][Oo][Rr]") then
  --if response.body:find("SERVER ERROR") then
    --return true
  --end
  
  --zl3
  print("before exit!")
  crete.mexit(0)
  --zl3
  return false
end

-- check from response if request was too big
local function request_too_big(response)
  return response.status==413 or response.status==414
end

-- checks if a field is of type we want to fuzz
local function fuzzable(field_type)
  return field_type=="text" or field_type=="radio" or field_type=="checkbox" or field_type=="textarea"
end

-- generates postdata with value of "sampleString" for every field (that is fuzzable()) of a form
local function generate_safe_postdata(form)
  local postdata = {}
  for _,field in ipairs(form["fields"]) do
    --zl3
    print("entered generate")
    print(field["name"])
    if fuzzable(field["type"]) then
      postdata[field["name"]] = "sampleString"
    end
  end
  return postdata
end

-- generate a charset of characters with ascii codes from 33 to 126
-- you can use http://www.asciitable.com/ to see which characters those actually are
local charset = generate_charset(33,126)
local charset_number = generate_charset(49,57) -- ascii 49 -> 1; 57 -> 9

local function fuzz_form(form, minlen, maxlen, host, port, path)
  local affected_fields = {}
  local postdata = generate_safe_postdata(form)
  local action_absolute = httpspider.LinkExtractor.isAbsolute(form["action"])
  --zl3
  print(action_absolute)

  -- determine the path where the form needs to be submitted
  local form_submission_path
  --zl3 
  --if action_absolute then
  if true then
    form_submission_path = form["action"]
  else
    local path_cropped = string.match(path, "(.*/).*")
    path_cropped = path_cropped and path_cropped or ""
    form_submission_path = path_cropped..form["action"]
    --zl3
    print(form_submission_path)
  end

  -- determine should the form be sent by post or get
  local sending_function
  local zl_response
  if form["method"]=="post" then
    print("got here 1")
    sending_function = function(data)
      zl_response = http.post(host, port, form_submission_path, nil, nil, data)
      print(zl_response.status)
      --print(zl_response.body)
      return zl_response 
    end
    --return http.post(host, port, form_submission_path, nil, nil, data) end
  else
    sending_function = function(data) return http.get(host, port, form_submission_path.."?"..url.build_query(data), {no_cache=true, bypass_cache=true}) end
  end

  local function fuzz_field(field)
    --zl3
    print("enter fuzz_field")
    local affected_string = {}
    local affected_int = {}

    --for i=minlen,maxlen do -- maybe a better idea would be to increment the string's length by more then 1 in each step
    for i=11,11 do -- maybe a better idea would be to increment the string's length by more then 1 in each step
      local response_string
      local response_number

      --first try to fuzz with a string
      postdata[field["name"]] = rand.random_string(i, charset)
      --zl3
      --print(postdata[field["name"]])
      response_string = sending_function(postdata)
      --then with a number
      --postdata[field["name"]] = stdnse.generate_random_string(i, charset_number)
      --response_number = sending_function(postdata)

      if check_response(response_string) then
        affected_string[#affected_string+1]=i
      elseif request_too_big(response_string) then
        maxlen = i-1
        break
      end

      --if check_response(response_number) then
        --affected_int[#affected_int+1]=i
      --elseif request_too_big(response_number) then
        --maxlen = i-1
        --break
      --end
    end
    postdata[field["name"]] = "sampleString"
    return affected_string, affected_int
  end

  for _,field in ipairs(form["fields"]) do
    if fuzzable(field["type"]) then
      local affected_string, affected_int = fuzz_field(field, minlen, maxlen, postdata, sending_function)
      --zl3
      print("affected_string number")
      print(#affected_string)
      
      if #affected_string > 0 or #affected_int > 0 then
        local affected_next_index = #affected_fields+1
        affected_fields[affected_next_index] = {name = field["name"]}
        if #affected_string>0 then
          table.insert(affected_fields[affected_next_index], {name="string lengths that caused errors:", table.concat(affected_string, ", ")})
        end
        if #affected_int>0 then
          table.insert(affected_fields[affected_next_index], {name="integer lengths that caused errors:", table.concat(affected_int, ", ")})
        end
      end
    end
  end
  return affected_fields
end

portrule = shortport.http

function action(host, port)
  local targets = stdnse.get_script_args('http-form-fuzzer.targets') or {{path="/loginclass/login.jsp"}}
  local return_table = {}
  --zl3
  local minlen = stdnse.get_script_args("http-form-fuzzer.minlength") or 11
  local maxlen = stdnse.get_script_args("http-form-fuzzer.maxlength") or 11

  for _,target in pairs(targets) do
    stdnse.debug2("testing path: "..target["path"])
    local path = target["path"]
    if path then
      local response = http.get( host, port, path )
      local all_forms = http.grab_forms(response.body)
      minlen = target["minlength"] or minlen
      maxlen = target["maxlength"] or maxlen
      for _,form_plain in ipairs(all_forms) do
        --zl3
        --print(form_plain)
        local form = http.parse_form(form_plain)
        --zl3
        --print(form["fields"])
        if form and form.action then
          local affected_fields = fuzz_form(form, minlen, maxlen, host, port, path)
          if #affected_fields > 0 then
            affected_fields["name"] = "Path: "..path.." Action: "..form["action"]
            table.insert(return_table, affected_fields)
          end
        end
      end
    end
  end
  return stdnse.format_output(true, return_table)
end

