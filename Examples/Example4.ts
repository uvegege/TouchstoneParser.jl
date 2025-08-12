! 4-port S-parameter data
! Option line reference resistance is overridden by [Reference]Touchstone® File Format Specification Version 2.1
! Data cannot be represented using 1.0 syntax,
! but can be represented using 1.1 syntax
! Note that the [Reference] keyword arguments appear on a separate line
[Version] 2.1
# GHz S MA R 50
[Number of Ports] 4
[Reference]
50 75 0.01 0.01
[Number of Frequencies] 1
Example 5 (Version 1.1):
! 4-port S-parameter data
! Per port reference provided using Version 1.1 syntax
# GHz S MA R 0.01 0.01 50.0 50.0