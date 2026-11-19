#!/usr/bin/env python3
"""Regenerate Layl.xcodeproj from the Swift sources. Run after adding a file."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Layl"
PROJECT = ROOT / "Layl.xcodeproj"

SWIFT_DIRS = [
    ("", ["LaylApp.swift"]),
    ("Model", ["Models.swift", "Catalog.swift", "AppModel.swift", "StreamingModels.swift"]),
    ("Design", ["Theme.swift", "LayoutMetrics.swift"]),
    ("Services", ["StreamingAvailabilityAPI.swift"]),
    ("Views", [
        "Components.swift",
        "ProfilePickerView.swift",
        "HomeView.swift",
        "TitleDetailView.swift",
        "PlayerView.swift",
        "LibraryViews.swift",
        "MainShell.swift",
        "DiscoverView.swift",
        "SettingsView.swift",
        "StreamingViews.swift",
    ]),
]


class Ids:
    def __init__(self):
        self.n = 0xA110000000000000

    def next(self):
        self.n += 1
        return f"{self.n:024X}"


ids = Ids()
file_refs = {}
build_files = {}


def fid(key):
    file_refs.setdefault(key, ids.next())
    return file_refs[key]


def bid(key):
    build_files.setdefault(key, ids.next())
    return build_files[key]


sources_phase = ids.next()
resources_phase = ids.next()
frameworks_phase = ids.next()
target = ids.next()
project = ids.next()
main_group = ids.next()
layl_group = ids.next()
products_group = ids.next()
product_ref = ids.next()
target_list = ids.next()
project_list = ids.next()
debug_project = ids.next()
release_project = ids.next()
debug_target = ids.next()
release_target = ids.next()
info_ref = fid("info")
privacy_ref = fid("privacy")
assets_ref = fid("assets")
privacy_build = bid("privacy")
assets_build = bid("assets")

groups = {}
source_build_ids = []
for folder, names in SWIFT_DIRS:
    children = []
    for name in names:
        key = f"{folder}/{name}"
        ref = fid(key)
        build = bid(key)
        source_build_ids.append(build)
        children.append((name, ref))
    groups[folder] = (ids.next(), children)

model_group, model_children = groups["Model"]
design_group, design_children = groups["Design"]
services_group, services_children = groups["Services"]
views_group, views_children = groups["Views"]
root_children = groups[""][1]


def file_ref_lines():
    lines = []
    for folder, names in SWIFT_DIRS:
        for name in names:
            ref = fid(f"{folder}/{name}")
            lines.append(
                f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
            )
    lines.append(
        f"\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};"
    )
    lines.append(
        f"\t\t{privacy_ref} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};"
    )
    lines.append(
        f"\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
    )
    lines.append(
        f"\t\t{product_ref} /* Layl.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Layl.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    return "\n".join(lines)


def build_file_lines():
    lines = []
    for folder, names in SWIFT_DIRS:
        for name in names:
            lines.append(
                f"\t\t{bid(f'{folder}/{name}')} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid(f'{folder}/{name}')} /* {name} */; }};"
            )
    lines.append(
        f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};"
    )
    lines.append(
        f"\t\t{privacy_build} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; fileRef = {privacy_ref} /* PrivacyInfo.xcprivacy */; }};"
    )
    return "\n".join(lines)


def child_block(pairs):
    return "\n".join(f"\t\t\t\t{ref} /* {name} */," for name, ref in pairs)


source_files_block = "\n".join(
    f"\t\t\t\t{bid(f'{folder}/{name}')} /* {name} in Sources */,"
    for folder, names in SWIFT_DIRS
    for name in names
)

common_target = r"""
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Layl/Info.plist;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.entertainment";
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.layl.streaming;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

project_common = r"""
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_VERSION = 5.0;
"""

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_file_lines()}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_ref_lines()}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group} = {{
			isa = PBXGroup;
			children = (
				{layl_group} /* Layl */,
				{products_group} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{products_group} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_ref} /* Layl.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{layl_group} /* Layl */ = {{
			isa = PBXGroup;
			children = (
				{root_children[0][1]} /* LaylApp.swift */,
				{model_group} /* Model */,
				{design_group} /* Design */,
				{services_group} /* Services */,
				{views_group} /* Views */,
				{assets_ref} /* Assets.xcassets */,
				{info_ref} /* Info.plist */,
				{privacy_ref} /* PrivacyInfo.xcprivacy */,
			);
			path = Layl;
			sourceTree = "<group>";
		}};
		{model_group} /* Model */ = {{
			isa = PBXGroup;
			children = (
{child_block(model_children)}
			);
			path = Model;
			sourceTree = "<group>";
		}};
		{design_group} /* Design */ = {{
			isa = PBXGroup;
			children = (
{child_block(design_children)}
			);
			path = Design;
			sourceTree = "<group>";
		}};
		{services_group} /* Services */ = {{
			isa = PBXGroup;
			children = (
{child_block(services_children)}
			);
			path = Services;
			sourceTree = "<group>";
		}};
		{views_group} /* Views */ = {{
			isa = PBXGroup;
			children = (
{child_block(views_children)}
			);
			path = Views;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* Layl */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_list} /* Build configuration list for PBXNativeTarget "Layl" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Layl;
			productName = Layl;
			productReference = {product_ref} /* Layl.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{target} = {{
						CreatedOnToolsVersion = 16.0;
					}};
				}};
			}};
			buildConfigurationList = {project_list} /* Build configuration list for PBXProject "Layl" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = ar;
			hasScannedForEncodings = 0;
			knownRegions = (
				ar,
				en,
				Base,
			);
			mainGroup = {main_group};
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* Layl */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_build} /* Assets.xcassets in Resources */,
				{privacy_build} /* PrivacyInfo.xcprivacy in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{source_files_block}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_project} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{project_common}
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{release_project} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{project_common}
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{debug_target} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{common_target}
			}};
			name = Debug;
		}};
		{release_target} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{common_target}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{project_list} /* Build configuration list for PBXProject "Layl" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_project} /* Debug */,
				{release_project} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_list} /* Build configuration list for PBXNativeTarget "Layl" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_target} /* Debug */,
				{release_target} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project} /* Project object */;
}}
"""

scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "Layl.app"
               BlueprintName = "Layl"
               ReferencedContainer = "container:Layl.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "Layl.app"
            BlueprintName = "Layl"
            ReferencedContainer = "container:Layl.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "Layl.app"
            BlueprintName = "Layl"
            ReferencedContainer = "container:Layl.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

workspace = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

# Confirm every referenced source exists before writing.
missing = []
for folder, names in SWIFT_DIRS:
    for name in names:
        path = SOURCE / folder / name if folder else SOURCE / name
        if not path.exists():
            missing.append(str(path))
if missing:
    raise SystemExit("Missing sources:\\n" + "\\n".join(missing))

proj_dir = PROJECT
(proj_dir).mkdir(exist_ok=True)
(proj_dir / "project.pbxproj").write_text(pbx, encoding="utf-8")
(proj_dir / "project.xcworkspace").mkdir(exist_ok=True)
(proj_dir / "project.xcworkspace" / "contents.xcworkspacedata").write_text(workspace, encoding="utf-8")
scheme_dir = proj_dir / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / "Layl.xcscheme").write_text(scheme, encoding="utf-8")
print(f"Wrote {proj_dir}")
print(f"Target id {target}")
