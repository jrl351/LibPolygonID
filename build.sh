#!/bin/bash

XCF_DIR=`pwd`
XCF_INCLUDE="$XCF_DIR/include"

set -e

buildWitness() {
  echo "Building witnesscalc..."

  WITNESS_FILES=(
    witnesscalc_authV2
    witnesscalc_credentialAtomicQueryMTPV2
    witnesscalc_credentialAtomicQueryMTPV2OnChain
    witnesscalc_credentialAtomicQuerySigV2
    witnesscalc_credentialAtomicQuerySigV2OnChain
    witnesscalc_credentialAtomicQueryV3
    witnesscalc_credentialAtomicQueryV3OnChain
    witnesscalc_linkedMultiQuery10
  )

  WITNESS_DIR="$XCF_DIR/../witnesscalc"
  WITNESS_PACKAGE_DIR="$WITNESS_DIR/package"

  WITNESS_IOS_DIR="$WITNESS_DIR/build_witnesscalc_ios"
  WITNESS_IOS_OUTPUT_DIR="$WITNESS_IOS_DIR/src/Release-iphoneos"

  WITNESS_IOS_SIM_DIR="$WITNESS_DIR/build_witnesscalc_ios_simulator"
  WITNESS_IOS_SIM_OUTPUT_DIR="$WITNESS_IOS_SIM_DIR/src/Release-iphonesimulator"

  WITNESS_LIBS="$XCF_DIR/witnesscalc/libs"
  WITNESS_TARGET="WitnessCalc.xcframework"

  cd $XCF_DIR
  rm -f $WITNESS_LIBS/*.a
  rm -Rf $WITNESS_TARGET

  cd $WITNESS_DIR

  git pull
  git submodule init
  git submodule update

  # MacOS - ARM
  set +e
  ./build_gmp.sh host
  set -e
  make arm64_host

  cp $WITNESS_PACKAGE_DIR/include/*.h $XCF_INCLUDE/

  mkdir -p $WITNESS_LIBS
  for file in "${WITNESS_FILES[@]}"; do
    cp "$WITNESS_PACKAGE_DIR/lib/lib$file.a" "$WITNESS_LIBS/lib$file-macos.a"
  done

  cp "$WITNESS_PACKAGE_DIR/lib/libfr.a" "$WITNESS_LIBS/libfr-macos.a"
  cp "$WITNESS_PACKAGE_DIR/lib/libgmp.a" "$WITNESS_LIBS/libgmp-macos.a"

  # iOS Simulator
  set +e
  ./build_gmp.sh ios_simulator
  set -e
  make ios-simulator
  mkdir -p $WITNESS_IOS_SIM_DIR
  cd $WITNESS_IOS_SIM_DIR
  for file in "${WITNESS_FILES[@]}"; do
    xcodebuild -project witnesscalc.xcodeproj \
      -destination 'generic/platform=iOS Simulator' \
      -configuration Release \
      -scheme ${file}Static
    cp $WITNESS_IOS_SIM_OUTPUT_DIR/lib$file.a $WITNESS_LIBS/lib$file-ios-sim.a
  done

  cd $WITNESS_DIR

  cp "$WITNESS_IOS_SIM_OUTPUT_DIR/libfr.a" "$WITNESS_LIBS/libfr-ios-sim.a"
  cp "$WITNESS_DIR/depends/gmp/package_iphone_simulator/lib/libgmp.a" "$WITNESS_LIBS/libgmp-ios-sim.a"

  # iOS
  set +e
  ./build_gmp.sh ios
  set -e
  make ios

  mkdir -p $WITNESS_IOS_DIR
  cd $WITNESS_IOS_DIR
  for file in "${WITNESS_FILES[@]}"; do
    xcodebuild -project witnesscalc.xcodeproj \
      -destination 'generic/platform=iOS' \
      -configuration Release \
      -scheme ${file}Static
    cp $WITNESS_IOS_OUTPUT_DIR/lib$file.a $WITNESS_LIBS/lib$file-ios.a
  done

  cd $WITNESS_DIR

  cp "$WITNESS_IOS_OUTPUT_DIR/libfr.a" "$WITNESS_LIBS/libfr-ios.a"
  cp "$WITNESS_DIR/depends/gmp/package_ios_arm64/lib/libgmp.a" "$WITNESS_LIBS/libgmp-ios.a"

  echo "Merging witnesscalc libraries..."

  rm -f $WITNESS_LIBS/witnesscalc-*
  libtool -static -no_warning_for_no_symbols \
    -o $WITNESS_LIBS/witnesscalc-macos.a \
    $WITNESS_LIBS/*-macos.a

  libtool -static -no_warning_for_no_symbols \
    -o $WITNESS_LIBS/witnesscalc-ios-sim.a \
    $WITNESS_LIBS/*-ios-sim.a

  libtool -static -no_warning_for_no_symbols \
    -o $WITNESS_LIBS/witnesscalc-ios.a \
    $WITNESS_LIBS/*-ios.a

  echo "Building witnesscalc framework..."

  cd $XCF_DIR
  xcodebuild -verbose -create-xcframework \
    -output $WITNESS_TARGET \
    -library $WITNESS_LIBS/witnesscalc-macos.a \
    -library $WITNESS_LIBS/witnesscalc-ios-sim.a \
    -library $WITNESS_LIBS/witnesscalc-ios.a
}

buildCPolygonID() {
  echo "Building c-polygon..."

  CPOLY_DIR="$XCF_DIR/../c-polygonid"
  CPOLY_LIBS="$XCF_DIR/cpolygon/libs"
  CPOLY_TARGET="CPolygonID.xcframework"

  cd $XCF_DIR

  rm -f $CPOLY_LIBS/*.a
  rm -Rf $CPOLY_TARGET

  cd $CPOLY_DIR
  git pull

  make ios-simulator
  make ios
  make darwin-arm64

  cp ios/libpolygonid.h "$XCF_INCLUDE"

  mkdir -p $CPOLY_LIBS
  cp ios/libpolygonid-darwin-arm64.a $CPOLY_LIBS/libpolygonid-macos.a
  cp ios/libpolygonid-ios.a $CPOLY_LIBS/libpolygonid-ios.a
  cp ios/libpolygonid-ios-simulator.a $CPOLY_LIBS/libpolygonid-ios-sim.a

  echo "Building xcframework..."
  cd "$XCF_DIR"
  xcodebuild -verbose -create-xcframework \
    -output $CPOLY_TARGET \
    -library $CPOLY_LIBS/libpolygonid-macos.a \
    -headers ./include/ \
    -library $CPOLY_LIBS/libpolygonid-ios-sim.a \
    -headers ./include/ \
    -library $CPOLY_LIBS/libpolygonid-ios.a \
    -headers ./include/
}

buildWitness
buildCPolygonID
