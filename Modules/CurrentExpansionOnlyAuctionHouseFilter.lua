-- local addonName, Private = ...

-- EnhanceQoL -> Economy > Auction House includes this

-- -- Auction House: Default "Current Expansion only" filter
-- local function FocusSearchBar(editBox, shouldFocus)
-- 	shouldFocus = shouldFocus or false
-- 	if not shouldFocus and editBox:HasFocus() then
-- 		editBox:ClearFocus()
-- 	end
-- 	if shouldFocus and not editBox:HasFocus() then
-- 		editBox:SetFocus()
-- 	end
-- end

-- local CraftOrdersFilterDropdownHooked = false
-- local AuctionHouseSearchBarHooked = false

-- EventRegistry:RegisterFrameEventAndCallback("CRAFTINGORDERS_SHOW_CUSTOMER", function()
-- 	if CraftOrdersFilterDropdownHooked then
-- 		return
-- 	end

-- 	CraftOrdersFilterDropdownHooked = true

-- 	-- Filter state is preserved on tab switch, but let's still enforce filter state in case a user has cleared it
-- 	local filterDropdown = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar.FilterDropdown
-- 	local searchBox = ProfessionsCustomerOrdersFrame.BrowseOrders.SearchBar.SearchBox

-- 	local function OnShow()
-- 		filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
-- 		filterDropdown:ValidateResetState()
-- 		FocusSearchBar(searchBox, true)
-- 	end

-- 	-- this enforces filter and focus state on tab switch
-- 	filterDropdown:HookScript("OnShow", function(filterDropdown)
-- 		-- schedule to run after current event and all OnShow callbacks
-- 		C_Timer.After(0, OnShow)
-- 	end)

-- 	-- for the first time it's too late for the hook to trigger, so run it explicitly
-- 	C_Timer.After(0, OnShow)
-- end)

-- EventRegistry:RegisterFrameEventAndCallback("AUCTION_HOUSE_SHOW", function()
-- 	if AuctionHouseSearchBarHooked then
-- 		return
-- 	end

-- 	AuctionHouseSearchBarHooked = true
-- 	-- this enforces filter state on tab switch
-- 	local searchBar = AuctionHouseFrame.SearchBar
-- 	local searchBox = AuctionHouseFrame.SearchBar.SearchBox

-- 	local function OnShow()
-- 		searchBar.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
-- 		searchBar:UpdateClearFiltersButton()
-- 		FocusSearchBar(searchBox, true)
-- 	end

-- 	-- this enforces filter and focus state on tab switch
-- 	searchBar:HookScript("OnShow", function(searchBar)
-- 		-- schedule to run after current event and all OnShow callbacks
-- 		C_Timer.After(0, OnShow)
-- 	end)
-- 	-- for the first time it's too late for the hook to trigger, so run it explicitly
-- 	C_Timer.After(0, OnShow)
-- end)
