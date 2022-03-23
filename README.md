# automated_test_emulator_run plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-automated_test_emulator_run)

<b>(article is deprecated - covered plugin version < 1.3.2 which doesn't support Build-Tools ver. >= 25.0.2)</b>
<br>See [blog post related to this plugin](https://medium.com/azimolabs/managing-android-virtual-devices-during-test-session-98a403acffc2#.upcmonil1). You can learn there how to create basic setup for this plugin step by step.

## About automated_test_emulator_run

Starts any number of AVDs. AVDs are created and configured automatically according to user liking before instrumentation test process starts (started either via shell command or from gradle) and killed/deleted after test process finishes.

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin.

1. To get started with `fastlane-plugin-automated_test_emulator_run`, add it to your project by running:

  ```bash
  fastlane add_plugin automated_test_emulator_run
  ```
2. Create your \*.JSON config file to create AVD launch plan according to schema below/provided example.

3. Wrap your test launch command with plugin and provide link to \*.JSON config.

## Example of Fastfile

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

## JSON config

What is JSON config?

It is a core of this plugin. User can specify any number of AVD devices in JSON file. Each AVD can be configured separately. Plugin will read JSON file and create fresh, new, untouched AVDs on host - use them in tests - and then delete them after test process finishes.

JSON file scheme:
```
{
    "avd_list":
    [
        {
          "avd_name": "",

          "create_avd_package": "",
          "create_avd_device": "",
          "create_avd_tag": "",
          "create_avd_abi": "",
          "create_avd_additional_options": "",
          "create_avd_hardware_config_filepath": "",

          "launch_avd_port": "",
          "launch_avd_snapshot_filepath": "",
          "launch_avd_launch_binary_name": "",
          "launch_avd_additional_options": ""
        }
    ]
}
```

Parameters:
<br>For official help refer to `avdmanager` binary file: `<sdk_root>/cmdline-tools/latest/bin/avdmanager create avd`
- `avd_name` - name of your AVD, avoid using spaces, this field is necessary
- `create_avd_package` - path to system image in example "system-images;android-23;google_apis;x86_64"
- `create_avd_device` - name of your device visible on `avdmanager list device` list
- `create_avd_tag` - the sys-img tag to use for the AVD. e.g. if you are using Google Apis then set it to "google_apis"
- `create_avd_abi` - abi for AVD e.g. "x86" or "x86_64" (https://developer.android.com/ndk/guides/abis.html)
- `create_avd_hardware_config_filepath` - path to config.ini file containing custom config for your AVD. After AVD is created this file will be copied into AVD location before it launches.
- `create_avd_additional_options` - if you think that you need something more you can just add your create parameters here (e.g. "--sdcard 128M", https://developer.android.com/studio/tools/help/android.html)
- `launch_avd_snapshot_filepath` - plugin might (if you set it) delete and re-create AVD before test start. That means all your permissions and settings will be lost on each emulator run. If you want to apply qemu image with saved AVD state you can put path to it in this field. It will be applied by using "-wipe-data -initdata <path to your file>"
- `launch_avd_launch_binary_name` - depending on your CPU architecture you need to choose binary file which should launch your AVD (e.g. "emulator", "emulator64-arm")
- `launch_avd_port` - port on which you wish your AVD should be launched, if you leave this field empty it will be assigned automatically
- `launch_avd_additional_options` - if you need more customization add your parameters here (e.g. "-gpu on -no-boot-anim -no-window", https://developer.android.com/studio/run/emulator-commandline.html)

Note:
- parameter `--path` is not supported, if you want to change directory to where your AVD are created edit your env variable ANDROID_SDK_HOME. Which is set to `~/.android/avd` by default.

Hints:
- <b> After change from `android` bin to `avdmanager` bin, default settings of AVD created from terminal has changed. No resolution is set. We highly recommend to use config.ini files which you can set to `create_avd_hardware_config_filepath` or specify resolution in `create_avd_additional_options`. </b>
- all fields need to be present in JSON, if you don't need any of the parameters just leave it empty
- pick even ports for your AVDs
- if you can't launch more than 2 AVDs be sure to check how much memory is your HAXM allowed to use (by default it is 2GB and that will allow you to launch around 2 AVDs) If you face any problems with freezing AVDs then be sure to reinstall your HAXM and allow it to use more of RAM (https://software.intel.com/en-us/android/articles/intel-hardware-accelerated-execution-manager)
- make sure you have all targets/abis installed on your PC if you want to use them (type in terminal: `android list targets`)
- we recommend adding `-gpu on` to your launching options for each device, it helps when working with many AVDs

Example:

[Example of complete JSON file can be found here.](fastlane/examples/AVD_setup.json)

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/PluginsTroubleshooting.md) doc in the main `fastlane` repo.

## Using `fastlane` Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Plugins.md).

## About `fastlane`

`fastlane` is the easiest way to automate building and releasing your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).


# Towards financial services available to all
We’re working throughout the company to create faster, cheaper, and more available financial services all over the world, and here are some of the techniques that we’re utilizing. There’s still a long way ahead of us, and if you’d like to be part of that journey, check out our [careers page](https://bit.ly/3vajnu6).
