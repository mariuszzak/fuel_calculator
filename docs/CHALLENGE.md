# Elixir Full-stack Challenge

Congratulations! NASA has awarded you a contract to build an advanced web application that calculates the required fuel for interplanetary travel. The goal of this application is to allow users to dynamically calculate the necessary fuel to launch from and land on various planets in the Solar System using Elixir, Phoenix, and LiveView.

## Objectives

### **1. Fuel Calculation Logic (Backend):**

Implement a backend solution using Elixir that calculates the required fuel based on the provided formulas:

- **Launch:** `mass * gravity * 0.042 - 33` (rounded down)
- **Landing:** `mass * gravity * 0.033 - 42` (rounded down)

For example, for Apollo 11 Command and Service Module, with weight of 28801 kg, to\
land it on the Earth, required amount of fuel will be:

> `28801 * 9.807 * 0.033 - 42 = 9278`

But fuel adds weight to the ship, so it requires additional fuel, until additional fuel is 0 or\
negative. Additional fuel is calculated using the same formula from above. Here is an example of the fuel calculation:

> 9278 fuel requires 2960 more fuel\
> 2960 fuel requires 915 more fuel\
> 915 fuel requires 254 more fuel\
> 254 fuel requires 40 more fuel\
> 40 fuel requires no more fuel

So, to land Apollo 11 CSM on the Earth - 13447 fuel required:

> `9278 + 2960 + 915 + 254 + 40 = 13447`

**Planets Supported (gravity):**

- Earth: 9.807
- Moon: 1.62
- Mars: 3.711

### **2. Phoenix Web Interface:**

Create a simple LiveView interface. Allow users to dynamically build a flight path, which contains a sequence of actions (`launch` or `land`) and planets. For example the flight path on UI could look like this:

> Launch - Earth\
> Land - Moon\
> Launch - Moon\
> Land - Earth

Also user should input spacecraft mass via the web interface. You can use Phoenix 1.8.0-rc, which has integrated DaisyUI library, and a set of predefined UI components to cover all your needs for this project. For simplicity you can omit usage of the database.

1. **Real-Time Updates with LiveView:**
    - Implement real-time updates using LiveView to immediately show calculated fuel requirements as the user inputs / adjusts their flight path and mass.
    - Provide dynamic UI interactions, such as adding/removing steps from the flight path.
2. **User Experience:**
    - Implement basic form validations (e.g., positive numeric inputs, selection validation).
    - Display calculation results clearly, showing the total fuel required

### **3. Maintainability and Quality:**

- Write **readable**, **maintainable**, and testable code.
- Use appropriate modules, contexts, and LiveView components.
- Ensure your code is idiomatic Elixir and Phoenix.

## Deliverables

- GitHub repository containing your project.
- Tests covering critical logic components. No full test coverage is required, so the final decision on what to test is on your side.

## Example Scenarios:

**Apollo 11 Mission:**

- Path: launch Earth, land Moon, launch Moon, land Earth
- Equipment mass: 28801 kg
- Total fuel required: 51898 kg

**Mars Mission:**

- Path: launch Earth, land Mars, launch Mars, land Earth
- Equipment mass: 14606 kg
- Total fuel required: 33388 kg

**Passenger Ship Mission:**

- Path: launch Earth, land Moon, launch Moon, land Mars, launch Mars, land Earth
- Equipment mass: 75432 kg
- Total fuel required: 212161 kg

### Good luck, engineer!
