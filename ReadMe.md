# JID

**J**ar **I**mport for **D**elphi

## Description

JID was created primarily as an alternative to Java2OP that ships with Delphi, in order to address some shortcomings in Java2OP.

As at Jan 21st 2024, JID will import specified classes, or all classes from the specified jar file. Presently, it will import from only **one jar file at a time**.

JID was written in a relatively short space of time, *may not create 100% perfect imports*, and is very likely to change, so **please bear this in mind**.

## Index Files

In order to resolve types from existing Delphi imports and include the relevant units in the uses clause, JID requires a "symbol index" file to be present in the same folder as the executable.  Index files are supplied with JID in the `Data` folder, with a name in the format: `androidrtl.nnn.json`, where `nnn` corresponds to the version of Delphi that the index was built for, e.g. `androidrtl.120.json` was built using the Android RTL files in Delphi 12.

## JID command line app usage

```
jid [-jar <jarfile>] -out <outfilename> [-cls <classes> | -file <clsfilename>]
```

Where:

* `<jarfile>` is the target jar
* `<classes>` are the classes to include, space delimited
* `<outfilename>` is the file to output to
* `<clsfilename>` file containing the classes to include

NOTE:

* In order to resolve identifiers/units from the Delphi RTL, a valid index file must be in the same folder as the executable. See: [Index Files](#index-files)
* You **must** have the `JAVA_HOME` environment variable set to the root of a *valid* JDK
* Class names **must** be fully qualified in dotted notation
* Filenames with spaces MUST be in quotes

Examples:

```
jid -jar exoplayer-core-2.19.1.jar -out Androidapi.JNI.Exployer.pas -cls com.google.android.exoplayer2.ExoPlayer
```

Will import `com.google.android.exoplayer2.ExoPlayer` and dependent classes in `exoplayer-core-2.19.1.jar` to `Androidapi.JNI.Exployer.pas`

```
  jid -out Androidapi.JNI.Rtl.pas -cls java.util.Formatter java.util.zip.Inflater
```

Will import `java.util.Formatter` and `java.util.zip.Inflater` to `Androidapi.JNI.Rtl.pas`

When omitting `-jar` (i.e. import from Java runtime), `-cls` or `-file` is required.

## Other JID functions

### Indexing

JID can also be used to create an "index" of all classes exported by `jar` files. The format of this command is:

```
jid -index <folder> -match <pattern> -out <outfilename>
```

Where:

* `<folder>` is a folder containing `jar` files
* `<pattern>` is a pattern for matching the `jar` filenames e.g a pattern of `exoplayer*` will result in indexing of all jar files starting with `exoplayer` in the folder
* `<outfilename>` is the file to output to

This is part of an example output:

```
com/google/android/exoplayer2/AbstractConcatenatedTimeline|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioBecomingNoisyManager$AudioBecomingNoisyReceiver|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioBecomingNoisyManager$EventListener|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioBecomingNoisyManager|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioFocusManager$AudioFocusListener|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioFocusManager$PlayerCommand|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioFocusManager$PlayerControl|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/AudioFocusManager|exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/BasePlayer|exoplayer-common-2.19.1.jar
com/google/android/exoplayer2/BaseRenderer|exoplayer-core-2.19.1.jar
```

Each line contains the fully qualified class, a separator `|`, and the file that contains the class.

The output can be useful for finding which `jar` files to include in a Delphi project when using Java classes that might belong to identical namespaces.
   
### Find

The format of the command is:

```
jid -find <classesfilename> <indexfilename> -out <outfilename>
```

* `<classesfilename>` is file containing a list of fully qualified class names on separate lines
* `<indexfilename>` is an index file produced by the `index` function 
* `<outfilename>` is the file to output to

The find function will match classes in "classes" file with classes in the "index" file, and output a list of the classes and each `jar` file they are contained in, e.g. for a "classes" file containing:

```
com/google/android/exoplayer2/BuildConfig
com/google/android/exoplayer2/DefaultMediaClock
com/google/android/exoplayer2/DeviceInfo
com/google/android/exoplayer2/FormatHolder
com/google/android/exoplayer2/MediaItem
```

Would result in an output of:

```
File: exoplayer-2.19.1.jar
com/google/android/exoplayer2/BuildConfig

File: exoplayer-common-2.19.1.jar
com/google/android/exoplayer2/DeviceInfo
com/google/android/exoplayer2/MediaItem

File:
exoplayer-core-2.19.1.jar
com/google/android/exoplayer2/DefaultMediaClock
com/google/android/exoplayer2/FormatHolder
```

Making it easier to know which `jar` files to include in a project

## Compiling JID

### Delphi versions

JID will compile in Delphi 12, and possibly earlier versions

### Dependencies

JID requires the following:

* [Kastri](https://github.com/DelphiWorlds/Kastri)
* [Delphi AST](https://github.com/RomanYankovsky/DelphiAST)
* [NEON](https://github.com/paolo-rossi/delphi-neon)

The JID project search paths make use of `User System Overrides` (These can be set up in the IDE options Tools | Options, IDE > Environment Variables), which point to the folders of the respective dependencies. Either create matching overrides in your IDE, or update the project search paths so that the compiler finds them.

## Support

### Issues page

If you encounter an issue, or want to request an enhancement, please [visit the issues page](https://github.com/DelphiWorlds/JID/issues) to report it.

### Slack Channel

The Delphi Worlds Slack workspace can be used to discuss aspects of JID. If you would like to join the Delphi Worlds Slack workspace, [please visit this self-invite link](https://slack.delphiworlds.com)

## Version History

v1.0.0 (Jan 21st, 2024)

* Initial release
