# SciMiner Quick Installation Commands

## One-Liner Solution (In Conda Environment)

```bash
# 1. Activate conda environment
conda activate sciminer

# 2. Install conda-forge packages
conda install -c conda-forge libxcrypt perl-dbd-mysql perl-dbd-sqlite

# 3. Install DBI with force
cpanm DBI --force

# 4. Install all required modules
cpanm -i YAML YAML::XS Text::NSP CGI CGI::Session HTML::Template XML::LibXML Spreadsheet::WriteExcel

# 5. Install any missing system packages
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl
```

## Complete Setup

```bash
# Activate conda environment
conda activate sciminer

# Install dependencies
conda install -y make gcc_linux-64 gxx_linux-64 libxml2 libxslt expat

# CRITICAL: Install database packages in this order
conda install -c conda-forge libxcrypt
conda install -c conda-forge perl-dbd-mysql
conda install -c conda-forge perl-dbd-sqlite

# Install DBI with force flag
cpanm DBI --force

# Install all required Perl modules
cpanm -i YAML YAML::XS Text::NSP CGI CGI::Session HTML::Template XML::LibXML Spreadsheet::WriteExcel

# Install system packages for any remaining modules
sudo apt-get install -y libcgi-pm-perl libhtml-template-perl libdbi-perl libdbd-mysql-perl

# Update Apache configuration
sudo bash /home/sciminer/update_apache_conda.sh

# Test installation
curl http://localhost:8888/SciMiner/test_environment.cgi
```

## Key Points

1. **Always install conda-forge packages FIRST**
2. **Use `--force` flag for DBI after conda-forge packages**
3. **Order matters**: libxcrypt → perl-dbd-mysql → DBI --force
4. **System packages are fallback** for modules that cpanm can't install

## Verification

```bash
# Test modules
perl -MDBI -e 'print "DBI version: $DBI::VERSION\n"'
perl -MDBD::MySQL -e 'print "DBD::MySQL loaded\n"'
perl -MBoulder::Medline -e 'print "Boulder::Medline loaded\n"'

# Test web interface
curl http://localhost:8888/SciMiner/
```