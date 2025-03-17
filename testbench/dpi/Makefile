# Compiler
CXX = g++
CXXFLAGS = -c -fPIC -I$(DSIM_HOME)/include/
LDFLAGS = -shared

TARGET = rv32i_tb.so

# Source and Object Files
SOURCES = rvfi_dii.cpp rvfi_ext.cpp
OBJECTS = $(SOURCES:.cpp=.o)

all: $(TARGET)

# Compile each .cpp into .o
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

# Link object files into shared library
$(TARGET): $(OBJECTS)
	$(CXX) $(LDFLAGS) -o $@ $^

clean:
	rm -f $(OBJECTS) $(TARGET)

