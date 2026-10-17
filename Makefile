.PHONY: all build lazarus

all: build

build:
	lazbuild --widgetset=qt5 packages/LcaDesignSystem/LcaDesignSystem.lpk
	lazbuild --widgetset=qt5 lazycodingagent.lpi

lazarus:
	./scripts/run-lazarus-linux.sh
