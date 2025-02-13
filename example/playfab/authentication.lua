--- This module will wrap the authentication towards PlayFab.
-- A user will either be logged in using a generated id or
-- using a stored username and password

local playfab = require "PlayFab.PlayFabClientApi"
local savetable = require "ludobits.m.io.savetable"
local listener = require "ludobits.m.listener"
local firstStart = true
local userid = ""
local playFabId = ""

local M = {
	listeners = listener.create()
}

--- Will be triggered when successfully logged in
M.LOGIN_SUCCESS = hash("playfab.login_success")

--- Will be triggered if login failed for some reason
M.LOGIN_FAILED = hash("playfab.login_failed")

--- Will be triggered when logging out
M.LOGOUT_SUCCESS = hash("playfab.logout_success")

--- Will be triggered when registration was successful
M.REGISTRATION_SUCCESS = hash("playfab.registration_success")

--- Will be triggered when registration failed for some reason
M.REGISTRATION_FAILED = hash("playfab.registration_failed")


local function generate_id()
	--[[for _,a in ipairs(sys.get_ifaddrs()) do
		if a.up and a.running then
			return a.mac
		end
	end--]]
	local id = ""
	for i=1,20 do
		id = id .. string.char(math.random(33, 126))
	end
	print("GENERATED ID", id)
	return id
end

--- Check if username and password was used when authenticating the user
-- @return true if username and password was used
function M.has_username_and_password()
	local auth = savetable.open("auth").load()
	return auth.username and auth.password
end


--- Get the user id of the currently logged in player
-- @return User id
function M.user_id()
	local auth = savetable.open("auth").load()
	if auth and auth.response and auth.response.PlayFabId ~= nil then 
		print("M.user_id 1")
		return auth and auth.response and auth.response.PlayFabId
	else 
		print("M.user_id 2")
		return playFabId
	end
end

function M.username()
	local auth = savetable.open("auth").load()
	return auth.username
end

-- PlayFabClientApi.LoginWithCustomID (id, generated)
-- PlayFabClientApi.LoginWithAndroidDeviceID (id, from device)
-- PlayFabClientApi.LoginWithFacebook (token)
-- PlayFabClientApi.LoginWithIOSDeviceID (id, from device)
-- PlayFabClientApi.LoginWithPlayFab (username+password)
-- PlayFabClientApi.AddUsernamePassword

--- Performa a login towards PlayFab. The login will either be done
-- using a generated PlayFab id or using a stored username and
-- password
-- Will trigger either @{LOGIN_SUCCESS} or @{LOGIN_FAILED}
-- @param username Optional username
-- @param password Optional password
function M.login(username, password)
	local auth = savetable.open("auth").load() or {}
	auth.username = username or auth.username
	auth.password = password or auth.password
	if firstStart then
		userid = auth.id
		playFabId = auth and auth.response and auth.response.PlayFabId
		print("User id saved!!!", userid, playFabId)
		firstStart = false
	end
	print("AUTH SAVE TABLE", auth.username, auth.password, auth.id)
	print("User id:", userid, playFabId)
	if auth.username and auth.password then
		local request = {
			TitleId = playfab.settings.titleId,
			Username = auth.username,
			Password = auth.password,
		}
		print("DEBUG - NO INTERNET USER PASWD")
		local response, error = playfab.LoginWithPlayFab.flow(request)
		print("DEBUG - NO INTERNET USER PASWD AFTER")
		if error then
			auth.username = nil
			auth.password = nil
			M.listeners.trigger(M.LOGIN_FAILED, error)
		else
			auth.response = response
			print("LOGIN NP")
			M.listeners.trigger(M.LOGIN_SUCCESS, response)
		end
		savetable.open("auth").save(auth)
		return response, error
	else
		auth.id = auth.id or userid or generate_id() 
		local request = {
			TitleId = playfab.settings.titleId,
			CustomId = auth.id,
			CreateAccount = true,
		}
		print("DEBUG - NO INTERNET ID")
		local response, error = playfab.LoginWithCustomID.flow(request)
		print("DEBUG - NO INTERNET ID AFTER")
		if error then
			auth.id = nil
			M.listeners.trigger(M.LOGIN_FAILED, error)
		else
			print("LOGIN ID")
			auth.response = response
			M.listeners.trigger(M.LOGIN_SUCCESS, response)
		end
		savetable.open("auth").save(auth)
		return response, error

		-- local response, error = playfab.LoginWithCustomID.flow(request,
		-- function(response)
		-- 	print("LOGIN ID")
		-- 	auth.response = response
		-- 	M.listeners.trigger(M.LOGIN_SUCCESS, response)
		-- end,
		-- function(error)
		-- 	print("DEBUG - NO INTERNET ID AFTER")
		-- 	auth.id = nil
		-- 	M.listeners.trigger(M.LOGIN_FAILED, error)
		-- end)
		-- savetable.open("auth").save(auth)
		-- return response, error
	end
end


--- Logout
-- This will clear any stored credentials
function M.logout()
	savetable.open("auth").save({})
	M.listeners.trigger(M.LOGOUT_SUCCESS, response)
	M.login()
end


--- Register a username, password and email
function M.register(username, password, email)
	if M.has_username_and_password() then
		return false, "The current account already has a username and password"
	end
	local auth = savetable.open("auth").load()
	local request = {
		TitleId = "979BE",
		Username = username,
		Email = email,
		Password = password,
		DisplayName = username,
	}
	pprint(request)
	local response, error = playfab.RegisterPlayFabUser.flow(request)
	if error then
		print("register error")
		pprint(error)
		M.listeners.trigger(M.REGISTRATION_FAILED, error)
	else
		pprint(response)
		auth.response = response
		auth.username = username
		auth.password = password
		savetable.open("auth").save(auth)
		M.listeners.trigger(M.REGISTRATION_SUCCESS, response)
	end
	return response, error
end



return M