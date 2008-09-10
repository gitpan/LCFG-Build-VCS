Name:           perl-LCFG-Build-VCS
Version:        0.0.20
Release:        1
Summary:        LCFG version control infrastructure
License:        GPLv2
Group:          Development/Libraries
Source0:        LCFG-Build-VCS-0.0.20.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
BuildRequires:  perl >= 1:5.6.1
BuildRequires:  perl(Module::Build)
BuildRequires:  perl(Moose) >= 0.57
BuildRequires:	perl(File::Copy::Recursive) >= 0.36
BuildRequires:	perl(Date::Format)
Requires:       perl(Moose) >= 0.57
Requires:	perl(File::Copy::Recursive) >= 0.36
Requires:       cvs, cvs2cl
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
This is a suite of tools designed to provide a standardised interface
to version-control systems so that the LCFG build tools can deal with
project version-control in a high-level abstract fashion. Typically
they provide support for procedures such as importing and exporting
projects, doing tagged releases, generating the project changelog from
the version-control log and checking all changes are committed.

More information on the LCFG build tools is available from the website
http://www.lcfg.org/doc/buildtools/


%prep
%setup -q -n LCFG-Build-VCS-%{version}

%build
%{__perl} Build.PL installdirs=vendor
./Build

%install
rm -rf $RPM_BUILD_ROOT

./Build install destdir=$RPM_BUILD_ROOT create_packlist=0
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;

%{_fixperms} $RPM_BUILD_ROOT/*

%check
./Build test

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc Changes README
%{perl_vendorlib}/LCFG/Build/VCS.pm
%{perl_vendorlib}/LCFG/Build/VCS/CVS.pm
%{perl_vendorlib}/LCFG/Build/VCS/None.pm
%doc %{_mandir}/man3/*

%changelog
* Wed Sep 10 2008 <<<< Release: 0.0.20 >>>>

* Wed Sep 10 2008 14:45 squinney
- Code clean-ups to try and make the path-handling more
  platform-independent. Lots of documentation improvements. Updated
  various dependencies.

* Wed Sep 03 2008 15:54 squinney

* Wed Sep 03 2008 15:52 squinney
- needed to be specific about version of the build-dependency on
  File::Copy::Recursive

* Wed Sep 03 2008 15:37 squinney

* Wed Sep 03 2008 15:31 squinney
- Added dependency on File::Copy::Recursive

* Wed Sep 03 2008 15:21 squinney

* Wed Sep 03 2008 15:21 squinney
- Added methods to support basic import and checkout for projects

* Thu Aug 14 2008 10:53 squinney

* Thu Aug 14 2008 10:51 squinney
- Moved the update_changelog method from the CVS module to a higher
  level so it can be used by other modules

* Thu Aug 14 2008 10:50 squinney
- Added support for a 'None' VCS module which just uses the
  filesystem

* Tue Jun 24 2008 14:46 squinney

* Tue Jun 24 2008 14:46 squinney
- switched to pre-processed files to get automated setting of
  version, author, etc.

* Mon Jun 23 2008 15:43 squinney

* Mon Jun 23 2008 15:42 squinney
- Fixed problem with finding relevant files for export_devel() for
  CVS where the list could contain deleted files waiting a commit

* Mon Jun 23 2008 13:38 squinney

* Mon Jun 23 2008 13:34 squinney
- Added support for a dry-run where commands are not actually
  executed. Also did some code tidying and checked with perlcritic

* Thu May 29 2008 11:04 squinney
- Modified the CVS export and export_devel methods to return the
  name of the created directory

* Tue May 13 2008 12:46 squinney
- no longer have any man1 files

* Tue May 13 2008 12:40 squinney

* Tue May 13 2008 12:02 squinney
- Moved lcfg-reltool to LCFG-Build-Tools to simplify dependencies

* Fri Mar 07 2008 14:27 squinney

* Thu Mar 06 2008 10:22 squinney

* Thu Mar 06 2008 10:09 squinney
- cleaned Makefile.PL

* Tue Mar 04 2008 11:48 squinney

* Tue Mar 04 2008 11:42 squinney
- fixed export method for cvs

* Tue Mar 04 2008 10:29 squinney

* Tue Mar 04 2008 10:25 squinney
- Improved the handling of the workdir attribute

* Mon Mar 03 2008 21:26 squinney
- Fixed switching to working directory

* Mon Mar 03 2008 21:04 squinney
- fixed switch to work directory

* Mon Mar 03 2008 20:57 squinney

* Mon Mar 03 2008 20:57 squinney
- Added support for exporting CVS modules

* Thu Feb 28 2008 09:55 squinney
- Added Changes file to CVS

* Thu Feb 28 2008 09:54 squinney

* Thu Feb 28 2008 09:53 squinney
- Added simple release.mk so it is easy to use lcfg-reltool with
  make

* Wed Feb 20 2008 15:32 squinney
- Added Changes file

* Wed Feb 20 2008 15:32 squinney

* Wed Feb 20 2008 15:28 squinney
- Added basic documentation to LCFG::Build::VCS::CVS

* Wed Feb 20 2008 15:28 squinney
- Fixed small pod error

* Wed Feb 20 2008 15:28 squinney
- Fixed small pod error

* Wed Feb 20 2008 15:27 squinney
- Improved control over the changelog filename from lcfg-reltool

* Wed Feb 20 2008 15:27 squinney
- Noted that we are using CVS

* Wed Feb 20 2008 15:26 squinney
- Added dependency on Date::Format

* Wed Feb 20 2008 15:03 squinney
- Added documentation

* Tue Feb 19 2008 17:22 squinney
- First release of LCFG::Build::VCS


