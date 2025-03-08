# Compiler
CXX = g++
CXXFLAGS = -c -fPIC -I$(DSIM_HOME)/include/
LDFLAGS = -shared
TARGET = rv32i_tb.so
OBJECT = rvfi_dii.o
SOURCE = rvfi_dii.cpp

all: $(TARGET)

$(OBJECT): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $@ $<

$(TARGET): $(OBJECT)
	$(CXX) $(LDFLAGS) -o $@ $^

clean:
	rm -f $(OBJECT) $(TARGET)

