// Extended filter categories for ItemFilterCategory enum
enum ItemFilterCategory2 {
	// Values from ItemFilterCategory for ease of use
	Invalid = -1,
	RangedWeapons = 0,
	MeleeWeapons = 1,
	Clothes = 2,
	Consumables = 3,
	Grenades = 4,
	SoftwareMods = 5,
	Attachments = 6,
	Programs = 7,
	Cyberware = 8,
	Junk = 9,
	Quest = 11,
	NewWardrobeAppearances = 12,
	Buyback = 13,

	// New Values
	Iconic = 20,			// Iconic items
	CraftingPart = 21,		// Crafting and quickhack components
	CraftingRecipe = 22,	// Crafting and quickhack recepies (These don't actually appear in your backpack)
	Uncategorized = 23,		// Anything else
	AllCount = 24,	// Updated AllCount
}

// Refactor PopulateInventory, change local tagsToFilterOut variable into m_tagsToFilterOut field.
@addField(BackpackMainGameController)
private let m_tagsToFilterOut: array<CName>;

// Additional filters are controlled by the m_additionalFilters field.
@addField(BackpackMainGameController)
private let m_additionalFilters: array<ItemFilterCategory2>;

// Set inventory blacklist (quickhacks are no longer on it), and additional filters
@wrapMethod(BackpackMainGameController)
protected cb func OnInitialize() -> Bool {
	ArrayPush(this.m_tagsToFilterOut, n"HideInBackpackUI");
	ArrayPush(this.m_additionalFilters, ItemFilterCategory2.Iconic);
	ArrayPush(this.m_additionalFilters, ItemFilterCategory2.Quest);
	ArrayPush(this.m_additionalFilters, ItemFilterCategory2.Uncategorized);
	return wrappedMethod();
}

// Refactor PopulateInventory, use m_tagsToFilterOut and m_additionalFilters to manage filtering
@wrapMethod(BackpackMainGameController)
private final func PopulateInventory() -> Void {
	let dropItem: ItemModParams;
	let i: Int32;
	let limit: Int32;
	let playerItems: ref<inkHashMap>;
	let quantity: Int32;
	let tagsToFilterOut: array<CName>;
	let uiInventoryItem: ref<UIInventoryItem>;
	let values: array<wref<IScriptable>>;
	let wrappedItem: ref<WrappedInventoryItemData>;
	let wrappedItems: array<ref<IScriptable>>;
	let filterManager: ref<ItemCategoryFliterManager> = ItemCategoryFliterManager.Make();
	this.m_uiInventorySystem.FlushTempData();
	playerItems = this.m_uiInventorySystem.GetPlayerItemsMap();
	playerItems.GetValues(values);
	i = 0;
	limit = ArraySize(values);
	while i < limit {
		uiInventoryItem = values[i] as UIInventoryItem;
		if !ItemID.HasFlag(uiInventoryItem.GetID(), gameEItemIDFlag.Preview) && !uiInventoryItem.HasAnyTag(tagsToFilterOut) {
			if ArrayContains(this.m_itemDropQueueItems, uiInventoryItem.ID) {
				quantity = uiInventoryItem.GetQuantity(true);
				dropItem = this.GetDropQueueItem(uiInventoryItem.ID);
				if dropItem.quantity >= quantity {
				} else {
					uiInventoryItem.SetQuantity(quantity - dropItem.quantity);
					wrappedItem = new WrappedInventoryItemData();
					wrappedItem.DisplayContextData = this.m_itemDisplayContext;
					wrappedItem.IsNew = this.m_uiScriptableSystem.IsInventoryItemNew(uiInventoryItem.ID);
					wrappedItem.Item = uiInventoryItem;
					wrappedItem.NotificationListener = this.m_immediateNotificationListener;
					filterManager.AddItem(uiInventoryItem.GetFilterCategory());
					ArrayPush(wrappedItems, wrappedItem);
				};
			};
			wrappedItem = new WrappedInventoryItemData();
			wrappedItem.DisplayContextData = this.m_itemDisplayContext;
			wrappedItem.IsNew = this.m_uiScriptableSystem.IsInventoryItemNew(uiInventoryItem.ID);
			wrappedItem.Item = uiInventoryItem;
			wrappedItem.NotificationListener = this.m_immediateNotificationListener;
			filterManager.AddItem(uiInventoryItem.GetFilterCategory());
			ArrayPush(wrappedItems, wrappedItem);
		};
		i += 1;
	};
	filterManager.SortFiltersList();
	i = 0;
	while i < ArraySize(this.m_additionalFilters) {
		filterManager.AddFilter2(this.m_additionalFilters[i]);
		i += 1;
	}
	filterManager.AddFilter(ItemFilterCategory.AllItems);
	this.RefreshFilterButtons(filterManager.GetFiltersList());
	this.m_backpackItemsDataSource.Reset(wrappedItems);
}

// New method to add extended filters to ItemCategoryFliterManager
@addMethod(ItemCategoryFliterManager)
public final func AddFilter2(filter: ItemFilterCategory2) -> Void {
	this.AddFilter(IntEnum<ItemFilterCategory>(EnumInt(filter)));
}

// Make sure extended filter categories survive the "sorting" ItemCategoryFliterManager does
@wrapMethod(ItemCategoryFliterManager)
public final func SortFiltersList() -> Void {
	let i: Int32;
	let result: array<ItemFilterCategory>;
	if this.m_isOrderDirty {
		i = 0;
		while i < EnumInt(ItemFilterCategory2.AllCount) {
			if ArrayContains(this.m_filters, IntEnum<ItemFilterCategory>(i)) {
				ArrayPush(result, IntEnum<ItemFilterCategory>(i));
			}
			i += 1;
		}
		this.m_filters = result;
		this.m_isOrderDirty = false;
	}
}

// Add HasTag method to UIInventoryItem
@addMethod(UIInventoryItem)
public final func HasTag(tag: CName) -> Bool {
	return this.m_itemData.HasTag(tag);
}

// Implement the new item filter categories
@wrapMethod(ItemCategoryFliter)
public final static func FilterItem(filter: ItemFilterCategory, wrappedData: ref<WrappedInventoryItemData>) -> Bool {
	// Extended filter categories
	if IsDefined(wrappedData.Item) {
		switch filter {
			case ItemFilterCategory2.Iconic:
				return wrappedData.Item.IsIconic();
			case ItemFilterCategory2.CraftingPart:
				return wrappedData.Item.HasTag(n"CraftingPart");
			case ItemFilterCategory2.CraftingRecipe:
				return wrappedData.Item.IsRecipe();
			case ItemFilterCategory2.Uncategorized:
				return Equals(wrappedData.Item.GetFilterCategory(), ItemFilterCategory.Invalid)
					&& !wrappedData.Item.IsQuestItem()
					&& !wrappedData.Item.HasTag(n"CraftingPart")
					&& !wrappedData.Item.IsRecipe();
		}
	}
	// Basic filter categories
	return wrappedMethod(filter, wrappedData);
}

// Give new filter categories labels
@wrapMethod(ItemFilterCategories)
public final static func GetLabelKey(filterType: ItemFilterCategory) -> CName {
	// Check extended categories
	switch filterType {
		case ItemFilterCategory2.Iconic:
			return n"Iconic Items";
		case ItemFilterCategory2.CraftingPart:
			return n"Crafting Materials";
		case ItemFilterCategory2.CraftingRecipe:
			return n"Crafting Specs";
		case ItemFilterCategory2.Uncategorized:
			return n"Others";
	}
	// Check base categories
	return wrappedMethod(filterType);
}

// Give new filter categories icons
@wrapMethod(ItemFilterCategories)
public final static func GetIcon(filterType: ItemFilterCategory) -> String {
	// Check extended categories
	switch filterType {
		case ItemFilterCategory2.Iconic:
			return "UIIcon.Filter_Iconic";
		case ItemFilterCategory2.CraftingPart:
			return "UIIcon.Filter_CraftingPart";
		case ItemFilterCategory2.CraftingRecipe:
			return "UIIcon.Filter_CraftingRecipe";
		case ItemFilterCategory2.Uncategorized:
			return "UIIcon.Filter_Uncategorized";
	}
	// Check base categories
	return wrappedMethod(filterType);
}

// Additional filters for player on FullscreenVendorGameController
@addField(FullscreenVendorGameController)
private let m_additionalPlayerFilters: array<ItemFilterCategory2>;

// Additional filters for vendor on FullscreenVendorGameController
@addField(FullscreenVendorGameController)
private let m_additionalVendorFilters: array<ItemFilterCategory2>;

// Additional filters for vendor on FullscreenVendorGameController
@addField(FullscreenVendorGameController)
private let m_additionalStorageFilters: array<ItemFilterCategory2>;

// Intialize additional filters
@wrapMethod(FullscreenVendorGameController)
private final func Init() -> Void {
	ArrayClear(this.m_additionalPlayerFilters);
	ArrayClear(this.m_additionalVendorFilters);
	ArrayPush(this.m_additionalVendorFilters, ItemFilterCategory2.CraftingPart);
	ArrayPush(this.m_additionalVendorFilters, ItemFilterCategory2.CraftingRecipe);
	ArrayClear(this.m_additionalStorageFilters);
	ArrayPush(this.m_additionalStorageFilters, ItemFilterCategory2.Iconic);
	wrappedMethod();
}

// Add new filters to FullscreenVendorGameController
@wrapMethod(FullscreenVendorGameController)
private final func SetFilters(root: inkWidgetRef, const data: script_ref<array<Int32>>, callback: CName) -> Void {
	// Extend player filters
	let i: Int32;
	if root == this.m_playerFiltersContainer {
		i = 0;
		while i < ArraySize(this.m_additionalPlayerFilters) {
			this.m_playerFilterManager.AddFilter2(this.m_additionalPlayerFilters[i]);
			i += 1;
		}
		data = this.m_playerFilterManager.GetIntFiltersList();
	}
	// Extend vendor filters
	if root == this.m_vendorFiltersContainer {
		if IsDefined(this.m_storageUserData) {
			i = 0;
			while i < ArraySize(this.m_additionalStorageFilters) {
				this.m_vendorFilterManager.AddFilter2(this.m_additionalStorageFilters[i]);
				i += 1;
			}
			data = this.m_vendorFilterManager.GetIntFiltersList();
		} else {
			// Drop points don't need additional filters as they have nothing to sell
			let dropPoint: ref<DropPoint> = this.m_VendorDataManager.GetVendorInstance() as DropPoint;
			if !IsDefined(dropPoint) {
				i = 0;
				while i < ArraySize(this.m_additionalVendorFilters) {
					this.m_vendorFilterManager.AddFilter2(this.m_additionalVendorFilters[i]);
					FTLog(">>> ADD: " + EnumInt(this.m_additionalVendorFilters[i]));
					i += 1;
				}
				data = this.m_vendorFilterManager.GetIntFiltersList();
			}
		}
	}
	// Call original method
	wrappedMethod(root, data, callback);
}
