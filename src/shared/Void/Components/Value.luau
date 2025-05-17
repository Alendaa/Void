--!strict

local Event = require("./Event")

export type new = (Value: any) -> ReactiveValue

type Module = {
    __call: (self: ReactiveValue, ...any) -> any,
    new: new
}

export type ReactiveValue = typeof(setmetatable({} :: {
    Value: any,
    Event: Event.Event,
}, {} :: Module))

local module: Module = {} :: Module
module.__call = function(self, ...): any
    local Value = table.pack(..., nil)[1] -- the nil exclude every value after index 1

    local OldValue = self.Value
    self.Value = if Value ~= nil then Value else self.Value

    self.Event:Fire(Value)

    return OldValue
end

function module.new<T>(Value: T): ReactiveValue
    if typeof(Value) == "nil" then
        return (nil :: any) :: ReactiveValue
    end

    local self: ReactiveValue = setmetatable({}, module) :: ReactiveValue
    self.Value = Value
    self.Event = Event.new()

    return self
end

return module
