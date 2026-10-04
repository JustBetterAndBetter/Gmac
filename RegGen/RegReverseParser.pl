#!/usr/bin/env perl
# -*- coding: utf-8 -*-
# 寄存器地址分配文件反向解析器
# 从带地址的寄存器表文件生成寄存器定义文件

use strict;
use warnings;
use utf8;
use Getopt::Long;
use File::Basename;
use File::Spec;

# 固定区域地址范围
my $FIXED_REGION_START = 0x00000000;
my $FIXED_REGION_END = 0x000000FF;

# 寄存器类
package Register;
sub new {
    my ($class, $name, $width, $reg_type, $default_value, $description, $address) = @_;
    my $self = {
        name => $name,
        width => $width,
        type => $reg_type,
        default_value => $default_value,  # 默认值
        description => $description,
        address => $address,
    };
    bless $self, $class;
    return $self;
}

# 表类
package Table;
sub new {
    my ($class, $name, $depth, $width, $description, $address) = @_;
    my $self = {
        name => $name,
        depth => $depth,
        width => $width,
        description => $description,
        address => $address,
        fields => [],
    };
    bless $self, $class;
    return $self;
}

# 表字段类
package TableField;
sub new {
    my ($class, $name, $offset, $field_hi, $field_lo, $description) = @_;
    my $self = {
        name => $name,
        offset => $offset,
        field_hi => $field_hi,
        field_lo => $field_lo,
        description => $description,
    };
    bless $self, $class;
    return $self;
}

# 主程序包
package main;

sub parse_hex_address {
    my ($addr_str) = @_;
    $addr_str =~ s/^\s+|\s+$//g;
    if ($addr_str =~ /^0x([0-9a-fA-F]+)$/i) {
        return hex($1);
    } elsif ($addr_str =~ /^([0-9a-fA-F]+)$/i) {
        return hex($1);
    }
    return undef;
}

sub parse_input_file {
    my ($filename) = @_;
    my @fixed_registers = ();  # 固定区域的寄存器
    my @registers = ();        # 普通寄存器
    my @tables = ();
    my $current_table = undef;
    
    open(my $fh, '<:encoding(utf8)', $filename) or die "Cannot open file $filename: $!";
    my @lines = <$fh>;
    close($fh);
    
    my $i = 0;
    my $in_fixed_section = 0;
    my $in_register_section = 0;
    my $in_table_section = 0;
    my $in_table_field_section = 0;
    
    while ($i < @lines) {
        my $line = $lines[$i];
        chomp($line);
        my $original_line = $line;
        $line =~ s/^\s+|\s+$//g;
        
        # 跳过空行
        if (!$line) {
            $i++;
            next;
        }
        
        # 跳过分隔线
        if ($line =~ /^#+$/) {
            $i++;
            next;
        }
        
        # 检查是否是表头行（支持带或不带defaultValue列）
        if ($line =~ /^name\s+address\s+offset\s+bit_range\s+width\s+type\s+(defaultValue\s+)?description/i) {
            $in_fixed_section = 0;
            $in_register_section = 1;
            $in_table_section = 0;
            $in_table_field_section = 0;
            $i++;
            next;
        }
        
        if ($line =~ /^name\s+address\s+depth\s+width\s+description/i) {
            $in_fixed_section = 0;
            $in_register_section = 0;
            $in_table_section = 1;
            $in_table_field_section = 0;
            $i++;
            next;
        }
        
        if ($line =~ /^name\s+offset\s+fieldHi\s+fieldLo\s+description/i) {
            $in_table_field_section = 1;
            $i++;
            next;
        }
        
        # 检查是否是MemName开始
        if ($line =~ /^MemName:\s*(.+)$/) {
            my $table_name = $1;
            $table_name =~ s/^\s+|\s+$//g;
            # 找到对应的表
            $current_table = undef;
            foreach my $table (@tables) {
                if ($table->{name} eq $table_name) {
                    $current_table = $table;
                    last;
                }
            }
            $in_table_field_section = 0;
            $i++;
            next;
        }
        
        # 解析寄存器行（固定区域或普通寄存器）
        if ($in_register_section && !$in_table_section && !$in_table_field_section) {
            # 解析格式：name address offset bit_range width type defaultValue description
            # 使用正则表达式匹配，因为defaultValue可能为空（多个空格）
            # 格式：name address offset bit_range width type [defaultValue] description
            if ($original_line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(.*)$/) {
                my $name = $1;
                my $address_str = $2;
                my $offset_str = $3;
                my $bit_range = $4;
                my $width = int($5);
                my $type = $6;
                my $rest = $7;  # 剩余部分：可能包含defaultValue和description
                
                my $default_value = "";
                my $description = "";
                
                # 尝试匹配defaultValue（Verilog格式：如 32'h0, 1'h1, 15'h123）
                # 如果匹配到defaultValue格式，则提取；否则整个rest都是description
                if ($rest =~ /^(\d+'[hbd][0-9a-fA-FxXzZ_]+)\s+(.+)$/) {
                    # 有defaultValue
                    $default_value = $1;
                    $description = $2;
                } elsif ($rest =~ /^(\d+'[hbd][0-9a-fA-FxXzZ_]+)$/) {
                    # 只有defaultValue，没有description
                    $default_value = $1;
                    $description = "";
                } else {
                    # 没有defaultValue，整个rest都是description
                    $description = $rest;
                }
                
                # 去除description首尾空白
                $description =~ s/^\s+|\s+$//g;
                
                my $address = parse_hex_address($address_str);
                if (defined $address) {
                    my $reg = Register->new($name, $width, $type, $default_value, $description, $address);
                    
                    # 判断是否是固定区域寄存器
                    if ($address >= $FIXED_REGION_START && $address <= $FIXED_REGION_END) {
                        push @fixed_registers, $reg;
                    } else {
                        push @registers, $reg;
                    }
                }
            }
            $i++;
            next;
        }
        
        # 解析表行
        if ($in_table_section && !$in_table_field_section) {
            # 解析格式：name address depth width description
            my @parts = split(/\s+/, $original_line);
            if (@parts >= 5) {
                my $name = $parts[0];
                my $address_str = $parts[1];
                my $depth = int($parts[2]);
                my $width = int($parts[3]);
                my $description = join(' ', @parts[4..$#parts]);
                
                my $address = parse_hex_address($address_str);
                if (defined $address) {
                    push @tables, Table->new($name, $depth, $width, $description, $address);
                }
            }
            $i++;
            next;
        }
        
        # 解析表字段行
        if ($in_table_field_section && defined $current_table) {
            # 解析格式：name offset fieldHi fieldLo description
            my @parts = split(/\s+/, $original_line);
            if (@parts >= 5) {
                my $name = $parts[0];
                # 检查是否是数字，如果不是则跳过（可能是表头行）
                if ($parts[1] !~ /^\d+$/) {
                    $i++;
                    next;
                }
                my $offset = int($parts[1]);
                my $field_hi = int($parts[2]);
                my $field_lo = int($parts[3]);
                my $description = join(' ', @parts[4..$#parts]);
                push @{$current_table->{fields}}, TableField->new($name, $offset, $field_hi, $field_lo, $description);
            }
            $i++;
            next;
        }
        
        $i++;
    }
    
    return (\@fixed_registers, \@registers, \@tables);
}

sub generate_output_file {
    my ($fixed_registers_ref, $registers_ref, $tables_ref, $output_filename) = @_;
    my @fixed_registers = @$fixed_registers_ref;
    my @registers = @$registers_ref;
    my @tables = @$tables_ref;
    
    open(my $fh, '>:encoding(utf8)', $output_filename) or die "Cannot open file $output_filename: $!";
    
    # 输出固定区域寄存器（如果有）
    if (@fixed_registers > 0) {
        print $fh "\n";
        print $fh "RegFixFieldDefine:\n";
        # 检查是否有默认值，决定是否输出默认值列
        my $has_default_value = 0;
        foreach my $reg (@fixed_registers) {
            if (defined $reg->{default_value} && $reg->{default_value} ne "") {
                $has_default_value = 1;
                last;
            }
        }
        if ($has_default_value) {
            printf $fh "%-20s %-10s %-10s %-15s %s\n", 'name', 'width', 'type', 'defaultValue', 'description';
            foreach my $reg (@fixed_registers) {
                my $default_value = (defined $reg->{default_value} && $reg->{default_value} ne "") ? $reg->{default_value} : '';
                printf $fh "%-20s %-10d %-10s %-15s %s\n",
                    $reg->{name}, $reg->{width}, $reg->{type}, $default_value, $reg->{description};
            }
        } else {
            printf $fh "%-20s %-10s %-10s %s\n", 'name', 'width', 'type', 'description';
            foreach my $reg (@fixed_registers) {
                printf $fh "%-20s %-10d %-10s %s\n",
                    $reg->{name}, $reg->{width}, $reg->{type}, $reg->{description};
            }
        }
        print $fh "\n";
    }
    
    # 输出普通寄存器（如果有）
    if (@registers > 0) {
        print $fh "RegFieldDefine:\n";
        # 检查是否有默认值，决定是否输出默认值列
        my $has_default_value = 0;
        foreach my $reg (@registers) {
            if (defined $reg->{default_value} && $reg->{default_value} ne "") {
                $has_default_value = 1;
                last;
            }
        }
        if ($has_default_value) {
            printf $fh "%-20s %-10s %-10s %-15s %s\n", 'name', 'width', 'type', 'defaultValue', 'description';
            foreach my $reg (@registers) {
                my $default_value = (defined $reg->{default_value} && $reg->{default_value} ne "") ? $reg->{default_value} : '';
                printf $fh "%-20s %-10d %-10s %-15s %s\n",
                    $reg->{name}, $reg->{width}, $reg->{type}, $default_value, $reg->{description};
            }
        } else {
            printf $fh "%-20s %-10s %-10s %s\n", 'name', 'width', 'type', 'description';
            foreach my $reg (@registers) {
                printf $fh "%-20s %-10d %-10s %s\n",
                    $reg->{name}, $reg->{width}, $reg->{type}, $reg->{description};
            }
        }
        print $fh "\n";
    }
    
    # 输出表定义（如果有）
    if (@tables > 0) {
        print $fh "MemFieldDefine:\n";
        printf $fh "%-20s %-10s %-10s %s\n", 'name', 'depth', 'width', 'description';
        foreach my $table (@tables) {
            printf $fh "%-20s %-10d %-10d %s\n",
                $table->{name}, $table->{depth}, $table->{width}, $table->{description};
        }
        print $fh " \n";
    }
    
    # 输出表字段定义（每个表单独输出）
    foreach my $table (@tables) {
        if (@{$table->{fields}} > 0) {
            print $fh "MemName:$table->{name}\n";
            printf $fh "%-20s %-10s %-10s %-10s %s\n", 'name', 'offset', 'fieldHi', 'fieldLo', 'description';
            foreach my $field (@{$table->{fields}}) {
                printf $fh "%-20s %-10d %-10d %-10d %s\n",
                    $field->{name}, $field->{offset}, $field->{field_hi},
                    $field->{field_lo}, $field->{description};
            }
            print $fh "\n";
        }
    }
    
    close($fh);
}

# 处理单个文件
sub process_single_file {
    my ($input_file) = @_;
    
    # 检查文件是否存在
    unless (-f $input_file) {
        die "Error: File not found: $input_file\n";
    }
    
    # 检查文件名是否以Reg.txt结尾
    unless ($input_file =~ /Reg\.txt$/i) {
        die "Error: File name must end with 'Reg.txt': $input_file\n";
    }
    
    # 获取文件路径和文件名（不含扩展名）
    my ($name, $dir, $ext) = fileparse($input_file, qr/Reg\.txt$/i);
    
    # 生成输出文件名：去掉Reg.txt后缀
    my $output_file = File::Spec->catfile($dir, $name);
    
    eval {
        # 解析输入文件
        print "Parsing input file: $input_file\n";
        my ($fixed_registers_ref, $registers_ref, $tables_ref) = parse_input_file($input_file);
        my @fixed_registers = @$fixed_registers_ref;
        my @registers = @$registers_ref;
        my @tables = @$tables_ref;
        print "Found " . scalar(@fixed_registers) . " fixed registers, " . scalar(@registers) . " registers and " . scalar(@tables) . " tables\n";
        
        # 生成输出文件
        print "Generating output file: $output_file\n";
        generate_output_file($fixed_registers_ref, $registers_ref, $tables_ref, $output_file);
        
        print "Done: $output_file\n";
    };
    
    if ($@) {
        print "Error processing $input_file: $@\n";
        return 0;
    }
    
    return 1;
}

# 主函数
my $file_arg = undef;

GetOptions(
    'f=s' => \$file_arg,
) or die "Usage: perl reg_reverse_parser.pl -f <Reg.txt_file>\n";

# 检查参数
if (!$file_arg) {
    die "Usage: perl reg_reverse_parser.pl -f <Reg.txt_file>\n" .
        "  -f <file>  : Parse a Reg.txt file, generate definition file without 'Reg.txt' suffix\n" .
        "Example: perl reg_reverse_parser.pl -f templateReg.txt\n" .
        "         (will generate template)\n";
}

# 处理单个文件
process_single_file($file_arg);

