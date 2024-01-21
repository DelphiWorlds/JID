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

## Functions yet to be documented

There are other functions of JID available via the commandline app (and via `TJIDCommand`, in the code) that are yet to be documented.

## Compiling JID

### Delphi versions

JID will compile in Delphi 12, and possibly earlier versions

### Dependencies

JID requires the following:

* [Kastri](https://github.com/DelphiWorlds/Kastri)
* [Delphi AST](https://github.com/RomanYankovsky/DelphiAST)
* [NEON](https://github.com/paolo-rossi/delphi-neon)

## Support

### Issues page

If you encounter an issue, or want to request an enhancement, please [visit the issues page](https://github.com/DelphiWorlds/JID/issues) to report it.

### Slack Channel

The Delphi Worlds Slack workspace can be used to discuss aspects of JID. If you would like to join the Delphi Worlds Slack workspace, [please visit this self-invite link](https://slack.delphiworlds.com)

## Version History

v1.0.0 (Jan 21st, 2024)

* Initial release
