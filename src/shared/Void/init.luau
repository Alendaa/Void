--!strict

local ComponentValue = require("./Void/Components/ReactiveValue")

export type ReactiveValue = ComponentValue.ReactiveValue

export type Structure<T> = {
	Class: string,
	Children: {[number]: Structure<T>?},
} & T

export type Gui<T> = typeof(setmetatable({} :: {}, {} :: Module)) & GuiProperties<T> & GuiMethods<T> & T

type GuiProperties<T> = {
	_Children: {[number]: {Name: string, Value: Gui<T>}},
	_Connections: {[string]: RBXScriptConnection}
}

type GuiMethods<T> = {
	FindFirstChild: <Child>(self: Gui<T>, Name: string, Recursive: boolean?) -> Gui<T>?,
	GetChildren: (self: Gui<T>) -> {[number]: Gui<T>}
}

type Module = {
	__index: (t: {[string]: any}, Key: string | number) -> any,
	__newindex: (t: {[string]: any}, Key: string, Value: any) -> (),
	
	New: <T>(Structure: Structure<T>) -> Gui<T>,
	
	ReactiveValue: ComponentValue.new
} & GuiMethods<any>


local function HasProperty(Object: any, Property: any): (boolean, any)
	return pcall(function()
		return Object[Property]
	end)
end

local Keys = {}
Keys.Accept = {
	FindFirstChild = true,
	_Instance = true,
	_Children = true,
	_Connections = true,
}

local module: Module = {} :: Module
module.__index = function(t, Key)
	local KeyType = typeof(Key)
	if KeyType ~= "string" then
		error(`Type of Key ~= string.`, 2)
	end
	
	if Keys.Accept[Key] then
		return module[Key]
	end

	local PropertyExist, PropertyValue = HasProperty(rawget(t, "_Instance"), Key)
	local ValueType = typeof(PropertyValue)
	if ValueType == "function" or ValueType == "RBXScriptSignal" then
		error(`You can't assing {ValueType} to {Key}.`, 2)
	end

	return if PropertyExist then PropertyValue else module[Key]
end

module.__newindex = function(t, Key, Value)
	if Keys.Accept[Key] then
		rawset(t, Key, Value)
		return
	end
	
	local Object = rawget(t, "_Instance")
	if not Object then
		return
	end

	local ValueType = typeof(Value)
	if ValueType == "function" or ValueType == "RBXScriptSignal" then
		error(`You can't assing {ValueType} to {Key}.`, 2)
	end

	(Object :: any)[Key] = Value
end

Keys.Reserved = {
	Children = function(Structure, self)
		for _, Properties in Structure.Children do
			if Properties.Parent == nil then
				Properties.Parent = self
			end
			
			local Child = module.New(Properties);
			(self._Children :: any)[Child] = {
				Value = Child,
				Name = Structure.Name or Structure.Class
			}
		end
	end,

	Events = function(_Structure, _self)
		
	end,

	Parent = function(Structure, self)
		local Parent = Structure.Parent
		local ParentType = typeof(Parent)

		if ParentType ~= "table" and ParentType ~= "nil" and ParentType ~= "Instance" then
			error("Unsuported type of Parent.", 2)
		end

		self._Instance.Parent = if ParentType == "Instance" then Parent
			elseif ParentType == "table" and getmetatable(Parent) == module then Parent._Instance
			else nil
	end
}

Keys.Ignore = {
	Class = true,
}

local function StructureToInstance<T>(Structure: {[string]: any}, self: Gui<T>): T
	local Class = Structure.Class
	if typeof(Class) ~= "string" then
		error(`Type of index Class is {typeof(Class)} ~= string.`, 2)
	end
	
	local Object = (Instance.new(Class) :: any) :: T
	self._Instance = Object

	for Property: string, Value: any in Structure do
		if Keys.Ignore[Property] then
			continue
		elseif Keys.Reserved[Property] then
			Keys.Reserved[Property](Structure, self, Object :: any)
			continue
		end

		local PropertyExist, ReturnedValue = HasProperty(Object, Property)
		if not PropertyExist then
			error(ReturnedValue, 2)
		end 	
		
		if typeof(Value) and typeof(ReturnedValue) == "function" then
			error("Read the docs to learn more about connecting events.", 2)
		end
		
		if typeof(Value) == "table" and getmetatable(Value) == ComponentValue then
			(Object :: any)[Property] = Value();

			table.insert(self._Connections, (Value :: ComponentValue.ReactiveValue).Event:Connect(function(NewValue: any)
				(Object :: any)[Property] = NewValue
			end))

			continue
		end

		(Object :: any)[Property] = Value
	end

	return Object
end

function module.New<T>(Structure: Structure<T>): Gui<T>
	local self: Gui<T> = setmetatable({}, module) :: Gui<T>
	self._Children = {}
	self._Connections = {}

	StructureToInstance(Structure, self)

	return self
end

function module:FindFirstChild<Child>(Name, Recursive): Gui<Child>?
	for _, Child in self._Children :: {[number]: {Name: string, Value: Gui<any>}} do
		if Child.Name == Name then
			return Child.Value
		end
	end

	if not Recursive then
		return
	end

	for _, Child in self._Children :: {[number]: {Name: string, Value: Gui<any>}} do
		local Grandchild = Child.Value:FindFirstChild(Name, true)
		if Grandchild then
			return Grandchild
		end
	end

	return
end

function module:GetChildren()
	local Children = {}
	for _, Child in self._Children :: {[number]: {Name: string, Value: Gui<any>}} do
		table.insert(Children, Child.Value)
	end

	return Children
end

module.ReactiveValue = ComponentValue.new

return module
