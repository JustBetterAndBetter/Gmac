#!/usr/bin/env perl
# -*- coding: utf-8 -*-
# 寄存器描述文件验证器
# 验证带地址的寄存器描述文件是否符合规范

use strict;
use warnings;
use utf8;

# 寄存器类型定义
my @REG_TYPES = qw(RO WO RW RI WI RIWI RIW RWI);

# 与 RegParser.pl 一致：各类型均独占 4 字节字地址，不在同一地址拼接
my @NON_MERGEABLE_TYPES = qw(RO WO RW RI WI RIWI RIW RWI);

# 可拼接的寄存器类型（当前与 RegParser 一致：无）
my @MERGEABLE_TYPES = ();

# 寄存器字对齐（字节）：与 RegParser 的 $ADDR_ALIGN 一致
my $ADDR_ALIGN = 0x4;

# 存储器表项位宽上限（比特）
my $TABLE_WIDTH_MAX = 65536;

# 将数组转换为哈希以便快速查找
my %NON_MERGEABLE_TYPES = map { $_ => 1 } @NON_MERGEABLE_TYPES;
my %MERGEABLE_TYPES = map { $_ => 1 } @MERGEABLE_TYPES;
my %REG_TYPES = map { $_ => 1 } @REG_TYPES;

# 寄存器信息类
package RegisterInfo;
sub new {
    my ($class, $name, $address, $offset, $width, $reg_type, $description) = @_;
    my $self = {
        name => $name,
        address => $address,
        offset => $offset,
        width => $width,
        type => $reg_type,
        description => $description,
        group => undef,
    };
    bless $self, $class;
    return $self;
}

# 表信息类
package TableInfo;
sub new {
    my ($class, $name, $address, $depth, $width, $description) = @_;
    my $self = {
        name => $name,
        address => $address,
        depth => $depth,
        width => $width,
        description => $description,
        fields => [],
    };
    bless $self, $class;
    return $self;
}

# 表字段信息类
package TableFieldInfo;
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

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

# 每个表项占用的 32bit 字数，与 RegRtlGenerator / RegParser 一致
sub memory_entry_size_words {
    my ($width_bits) = @_;
    my $w = int(($width_bits + 31) / 32);
    return $w < 1 ? 1 : $w;
}

# 解析 RegParser / RegRtlGenerator 输出的寄存器数据行
sub parse_flat_register_data_line {
    my ($raw) = @_;
    return undef unless defined $raw;
    chomp($raw);
    if ($raw =~ /^(\S+)\s+(0x[0-9a-fA-F]+)\s+(0x[0-9a-fA-F]+)\s+(\[[^\]]+\])\s+(\d+)\s+(\S+)\s+(.*)$/) {
        my $name = $1;
        my $address = hex($2);
        my $offset = hex($3);
        my $width = int($5);
        my $type = $6;
        my $rest = $7;
        my $description = $rest;
        if ($rest =~ /^(\d+'[hbd][0-9a-fA-FxXzZ_]+)\s+(.+)$/) {
            $description = $2;
        } elsif ($rest =~ /^(\d+'[hbd][0-9a-fA-FxXzZ_]+)$/) {
            $description = "";
        }
        $description =~ s/^\s+|\s+$//g;
        my $reg = RegisterInfo->new($name, $address, $offset, $width, $type, $description);
        $reg->{group} = $type;
        return $reg;
    }
    return undef;
}

sub parse_output_file {
    my ($filename) = @_;
    my @registers = ();
    my @tables = ();
    my $current_table = undef;
    my $current_group = undef;
    
    open(my $fh, '<:encoding(utf8)', $filename) or die "Cannot open file $filename: $!";
    my @lines = <$fh>;
    close($fh);
    
    my $i = 0;
    while ($i < @lines) {
        my $line = $lines[$i];
        chomp($line);
        $line =~ s/^\s+|\s+$//g;
        
        # 跳过空行、分隔线与 RegParser 使用的 # 分隔行
        if (!$line || $line =~ /^[=-]/ || $line =~ /^#+$/) {
            $i++;
            next;
        }
        
        # 解析寄存器组
        if ($line =~ /^RegGroup:\s*(.+)$/) {
            $current_group = $1;
            $current_group =~ s/^\s+|\s+$//g;
            $i++;
            # 读取base_address
            my $base_addr = 0;
            if ($i < @lines) {
                my $base_addr_line = $lines[$i];
                chomp($base_addr_line);
                $base_addr_line =~ s/^\s+|\s+$//g;
                if ($base_addr_line =~ /^base_address:\s*(.+)$/) {
                    $base_addr = hex($1);
                }
            }
            $i++;
            # 跳过offset_step行
            if ($i < @lines && $lines[$i] =~ /offset_step/) {
                $i++;
            }
            # 跳过表头行
            if ($i < @lines && $lines[$i] =~ /^\s*name/) {
                $i++;
            }
            # 跳过分隔线
            if ($i < @lines && $lines[$i] =~ /^-/) {
                $i++;
            }
            
            # 解析寄存器行
            while ($i < @lines) {
                my $reg_line = $lines[$i];
                chomp($reg_line);
                $reg_line =~ s/^\s+|\s+$//g;
                if (!$reg_line) {
                    $i++;
                    last;
                }
                # 检查是否是下一个section
                if ($reg_line =~ /^(RegGroup:|TableGroup:|MemName:)/) {
                    last;
                }
                
                # 解析：name address offset width type description
                my @parts = split(/\s+/, $reg_line);
                if (@parts >= 6) {
                    my $name = $parts[0];
                    my $address = ($parts[1] =~ /^0x/) ? hex($parts[1]) : int($parts[1]);
                    my $offset = ($parts[2] =~ /^0x/) ? hex($parts[2]) : int($parts[2]);
                    my $width = int($parts[3]);
                    my $reg_type = $parts[4];
                    my $description = join(' ', @parts[5..$#parts]);
                    my $reg = RegisterInfo->new($name, $address, $offset, $width, $reg_type, $description);
                    $reg->{group} = $current_group;
                    push @registers, $reg;
                }
                $i++;
            }
            next;
        }
        
        # 解析表组
        if ($line =~ /^TableGroup:/) {
            $i++;
            # 读取base_address
            if ($i < @lines) {
                my $base_addr_line = $lines[$i];
                chomp($base_addr_line);
                $base_addr_line =~ s/^\s+|\s+$//g;
                if ($base_addr_line =~ /^base_address:/) {
                    $i++;
                }
            }
            # 跳过表头行
            if ($i < @lines && $lines[$i] =~ /^\s*name/) {
                $i++;
            }
            # 跳过分隔线
            if ($i < @lines && $lines[$i] =~ /^-/) {
                $i++;
            }
            
            # 解析表行
            while ($i < @lines) {
                my $table_line = $lines[$i];
                chomp($table_line);
                $table_line =~ s/^\s+|\s+$//g;
                if (!$table_line) {
                    $i++;
                    last;
                }
                # 检查是否是MemName
                if ($table_line =~ /^MemName:/) {
                    last;
                }
                
                # 解析：name address depth width description
                my @parts = split(/\s+/, $table_line);
                if (@parts >= 5) {
                    my $name = $parts[0];
                    my $address = ($parts[1] =~ /^0x/) ? hex($parts[1]) : int($parts[1]);
                    my $depth = int($parts[2]);
                    my $width = int($parts[3]);
                    my $description = join(' ', @parts[4..$#parts]);
                    push @tables, TableInfo->new($name, $address, $depth, $width, $description);
                }
                $i++;
            }
            next;
        }
        
        # RegParser / RegRtlGenerator 扁平格式：寄存器块（含 bit_range、defaultValue 列）
        if ($line =~ /^name\s+address\s+offset\s+bit_range\s+width\s+type\b/i) {
            $i++;
            while ($i < @lines) {
                my $raw = $lines[$i];
                chomp($raw);
                my $t = $raw;
                $t =~ s/^\s+|\s+$//g;
                if (!$t) {
                    $i++;
                    next;
                }
                if ($t =~ /^#+$/) {
                    $i++;
                    next;
                }
                if ($t =~ /^name\s+address\s+offset\s+bit_range\s+width\s+type\b/i) {
                    $i++;
                    next;
                }
                if ($t =~ /^name\s+address\s+depth\s+width\s+description\b/i) {
                    last;
                }
                if ($t =~ /^MemName:/i) {
                    last;
                }
                if ($t =~ /^(RegGroup:|TableGroup:)/) {
                    last;
                }
                my $reg = parse_flat_register_data_line($raw);
                if ($reg) {
                    push @registers, $reg;
                }
                $i++;
            }
            next;
        }
        
        # 扁平格式：存储器列表（无 TableGroup）
        if ($line =~ /^name\s+address\s+depth\s+width\s+description\b/i) {
            $i++;
            while ($i < @lines) {
                my $raw = $lines[$i];
                chomp($raw);
                my $t = $raw;
                $t =~ s/^\s+|\s+$//g;
                if (!$t) {
                    $i++;
                    next;
                }
                if ($t =~ /^#+$/) {
                    $i++;
                    next;
                }
                if ($t =~ /^name\s+address\s+depth\s+width\s+description\b/i) {
                    $i++;
                    next;
                }
                if ($t =~ /^MemName:/i) {
                    last;
                }
                if ($t =~ /^(RegGroup:|TableGroup:)/) {
                    last;
                }
                if ($t =~ /^name\s+address\s+offset\s+bit_range\b/i) {
                    last;
                }
                if ($raw =~ /^(\S+)\s+(0x[0-9a-fA-F]+)\s+(\d+)\s+(\d+)\s+(.*)$/) {
                    my $name = $1;
                    my $address = hex($2);
                    my $depth = int($3);
                    my $width = int($4);
                    my $description = $5;
                    $description =~ s/^\s+|\s+$//g;
                    push @tables, TableInfo->new($name, $address, $depth, $width, $description);
                }
                $i++;
            }
            next;
        }
        
        # 解析表字段
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
            
            $i++;
            # 跳过表头行与 # 分隔行（RegParser 输出）
            while ($i < @lines) {
                my $peek = $lines[$i];
                chomp($peek);
                my $pt = $peek;
                $pt =~ s/^\s+|\s+$//g;
                last if !$pt;
                if ($pt =~ /^#+$/) {
                    $i++;
                    next;
                }
                if ($peek =~ /^\s*name\s+offset\s+fieldHi\s+fieldLo\b/i) {
                    $i++;
                    next;
                }
                last;
            }
            # 跳过分隔线
            if ($i < @lines && $lines[$i] =~ /^-/) {
                $i++;
            }
            
            # 解析字段行
            while ($i < @lines && $current_table) {
                my $field_line = $lines[$i];
                chomp($field_line);
                my $trim = $field_line;
                $trim =~ s/^\s+|\s+$//g;
                if (!$trim) {
                    $i++;
                    last;
                }
                if ($trim =~ /^#+$/) {
                    $i++;
                    next;
                }
                # 检查是否是下一个section
                if ($trim =~ /^(RegGroup:|TableGroup:|MemName:)/) {
                    last;
                }
                
                # 解析：name offset fieldHi fieldLo description（跳过列名表头行）
                my @parts = split(/\s+/, $field_line);
                if (@parts >= 5 && $parts[1] =~ /^\d+$/) {
                    my $name = $parts[0];
                    my $offset = int($parts[1]);
                    my $field_hi = int($parts[2]);
                    my $field_lo = int($parts[3]);
                    my $description = join(' ', @parts[4..$#parts]);
                    push @{$current_table->{fields}}, TableFieldInfo->new($name, $offset, $field_hi, $field_lo, $description);
                }
                $i++;
            }
            next;
        }
        
        $i++;
    }
    
    return (\@registers, \@tables);
}

sub validate_registers {
    my ($registers_ref) = @_;
    my @registers = @$registers_ref;
    my @errors = ();
    my @warnings = ();
    
    # 1. 检查名称唯一性
    my %names = ();
    foreach my $reg (@registers) {
        if (exists $names{$reg->{name}}) {
            push @errors, "Duplicate register name: $reg->{name} (first at " . sprintf("0x%08X", $names{$reg->{name}}) . ", second at " . sprintf("0x%08X", $reg->{address}) . ")";
        } else {
            $names{$reg->{name}} = $reg->{address};
        }
    }
    
    # 2. 检查类型有效性
    foreach my $reg (@registers) {
        if (!exists $REG_TYPES{$reg->{type}}) {
            push @errors, "Invalid register type '$reg->{type}' for register $reg->{name}";
        }
    }
    
    # 3. 检查位宽有效性
    foreach my $reg (@registers) {
        if ($reg->{width} < 1 || $reg->{width} > 32) {
            push @errors, "Invalid width $reg->{width} for register $reg->{name} (must be 1-32 bits)";
        }
    }
    
    # 4. 检查地址对齐
    foreach my $reg (@registers) {
        if ($reg->{address} % $ADDR_ALIGN != 0) {
            push @errors, "Address " . sprintf("0x%08X", $reg->{address}) . " for register $reg->{name} is not aligned to 0x" . sprintf("%X", $ADDR_ALIGN);
        }
        if ($reg->{offset} % $ADDR_ALIGN != 0) {
            push @errors, "Offset " . sprintf("0x%04X", $reg->{offset}) . " for register $reg->{name} is not aligned to 0x" . sprintf("%X", $ADDR_ALIGN);
        }
    }
    
    # 5. 检查地址冲突（同一地址的寄存器）
    my %addr_map = ();
    foreach my $reg (@registers) {
        push @{$addr_map{$reg->{address}}}, $reg;
    }
    
    foreach my $addr (keys %addr_map) {
        my @regs = @{$addr_map{$addr}};
        if (@regs > 1) {
            # 检查是否可以拼接
            my $can_merge = 1;
            my @reg_types = map { $_->{type} } @regs;
            
            # 检查类型是否允许拼接
            my $has_non_mergeable = 0;
            foreach my $t (@reg_types) {
                if (exists $NON_MERGEABLE_TYPES{$t}) {
                    $has_non_mergeable = 1;
                    last;
                }
            }
            if ($has_non_mergeable) {
                $can_merge = 0;
            } else {
                # 检查类型是否一致
                my %types = map { $_ => 1 } @reg_types;
                if (keys %types > 1) {
                    $can_merge = 0;
                }
            }
            
            if (!$can_merge) {
                my $names_str = join(', ', map { $_->{name} } @regs);
                push @errors, "Address conflict at " . sprintf("0x%08X", $addr) . ": $names_str (cannot be merged)";
            } else {
                # 检查位宽总和
                my $total_width = 0;
                foreach my $r (@regs) {
                    $total_width += $r->{width};
                }
                if ($total_width > 32) {
                    my $names_str = join(', ', map { $_->{name} } @regs);
                    push @errors, "Address " . sprintf("0x%08X", $addr) . ": total width $total_width exceeds 32 bits for $names_str";
                }
            }
        }
    }
    
    # 6. 检查拼接规则（方案2）
    # 按组检查
    my %groups = ();
    foreach my $reg (@registers) {
        push @{$groups{$reg->{group}}}, $reg;
    }
    
    foreach my $group_type (keys %groups) {
        my @regs = @{$groups{$group_type}};
        if (exists $NON_MERGEABLE_TYPES{$group_type}) {
            # 不能拼接的组，每个寄存器应该独占地址空间
            foreach my $reg (@regs) {
                # 检查是否有其他寄存器在同一地址
                my @same_addr_regs = grep { $_->{address} == $reg->{address} && $_ != $reg } @registers;
                if (@same_addr_regs > 0) {
                    my $names_str = join(', ', map { $_->{name} } @same_addr_regs);
                    push @errors, "Register $reg->{name} (type $reg->{type}) cannot share address with $names_str";
                }
            }
        } elsif (exists $MERGEABLE_TYPES{$group_type}) {
            # 可拼接的组，检查同一地址的寄存器是否符合规则
            my %addr_map = ();
            foreach my $reg (@regs) {
                push @{$addr_map{$reg->{address}}}, $reg;
            }
            
            foreach my $addr (keys %addr_map) {
                my @addr_regs = @{$addr_map{$addr}};
                if (@addr_regs > 1) {
                    # 检查类型是否一致
                    my %types = map { $_->{type} => 1 } @addr_regs;
                    if (keys %types > 1) {
                        my $names_str = join(', ', map { $_->{name} } @addr_regs);
                        my $types_str = join(', ', keys %types);
                        push @errors, "Address " . sprintf("0x%08X", $addr) . ": different types {$types_str} cannot be merged: $names_str";
                    }
                    
                    # 检查位宽总和
                    my $total_width = 0;
                    foreach my $r (@addr_regs) {
                        $total_width += $r->{width};
                    }
                    if ($total_width > 32) {
                        my $names_str = join(', ', map { $_->{name} } @addr_regs);
                        push @errors, "Address " . sprintf("0x%08X", $addr) . ": total width $total_width exceeds 32 bits: $names_str";
                    }
                }
            }
        }
    }
    
    return (\@errors, \@warnings);
}

sub validate_tables {
    my ($tables_ref) = @_;
    my @tables = @$tables_ref;
    my @errors = ();
    my @warnings = ();
    
    # 1. 检查名称唯一性
    my %names = ();
    foreach my $table (@tables) {
        if (exists $names{$table->{name}}) {
            push @errors, "Duplicate table name: $table->{name}";
        } else {
            $names{$table->{name}} = $table->{address};
        }
    }
    
    # 2. 检查深度有效性
    foreach my $table (@tables) {
        if ($table->{depth} < 1) {
            push @errors, "Invalid depth $table->{depth} for table $table->{name}";
        }
    }
    
    # 3. 检查位宽有效性（存储器总线可宽于 32，与 RegParser 一致）
    foreach my $table (@tables) {
        if ($table->{width} < 1 || $table->{width} > $TABLE_WIDTH_MAX) {
            push @errors, "Invalid width $table->{width} for table $table->{name} (must be 1-$TABLE_WIDTH_MAX bits)";
        }
    }
    
    # 4. 检查地址对齐
    foreach my $table (@tables) {
        if ($table->{address} % $ADDR_ALIGN != 0) {
            push @errors, "Address " . sprintf("0x%08X", $table->{address}) . " for table $table->{name} is not aligned to 0x" . sprintf("%X", $ADDR_ALIGN);
        }
    }
    
    # 5. 检查表字段
    foreach my $table (@tables) {
        # 检查同一表内字段名称唯一性（不同表的字段可以同名）
        my %field_names = ();
        foreach my $field (@{$table->{fields}}) {
            if (exists $field_names{$field->{name}}) {
                push @errors, "Table $table->{name}: duplicate field name '$field->{name}' (fields in different tables can have the same name, but fields within the same table must be unique)";
            } else {
                $field_names{$field->{name}} = 1;
            }
        }
        
        # 检查字段位范围
        foreach my $field (@{$table->{fields}}) {
            if ($field->{field_hi} < $field->{field_lo}) {
                push @errors, "Table $table->{name} field $field->{name}: fieldHi ($field->{field_hi}) < fieldLo ($field->{field_lo})";
            }
            if ($field->{field_hi} >= 32 || $field->{field_lo} < 0) {
                push @errors, "Table $table->{name} field $field->{name}: bit range [$field->{field_hi}:$field->{field_lo}] out of range [31:0]";
            }
        }
        
        # 同一 offset（32bit 字）内字段位宽之和不超过 32
        my %width_by_offset = ();
        foreach my $field (@{$table->{fields}}) {
            my $bits = $field->{field_hi} - $field->{field_lo} + 1;
            $width_by_offset{$field->{offset}} += $bits;
        }
        foreach my $off (keys %width_by_offset) {
            if ($width_by_offset{$off} > 32) {
                push @errors, "Table $table->{name} offset $off: total field width $width_by_offset{$off} exceeds 32 bits";
            }
        }
    }
    
    # 6. 检查表地址冲突
    # 检查地址重叠
    my @table_list = sort { $a->{address} <=> $b->{address} } @tables;
    for (my $i = 0; $i < @table_list - 1; $i++) {
        my $table1 = $table_list[$i];
        my $table2 = $table_list[$i + 1];
        my $esz = memory_entry_size_words($table1->{width});
        my $table1_end = $table1->{address} + $table1->{depth} * $esz * 4;
        if ($table1_end > $table2->{address}) {
            push @errors, "Table address overlap: $table1->{name} (" . sprintf("0x%08X", $table1->{address}) . "-" . sprintf("0x%08X", $table1_end) . ") overlaps with $table2->{name} (" . sprintf("0x%08X", $table2->{address}) . ")";
        }
    }
    
    return (\@errors, \@warnings);
}

sub validate_address_space {
    my ($registers_ref, $tables_ref) = @_;
    my @registers = @$registers_ref;
    my @tables = @$tables_ref;
    my @errors = ();
    my @warnings = ();
    
    # 检查寄存器与表地址冲突
    my %reg_addresses = ();
    foreach my $reg (@registers) {
        # 与 RegParser 一致：每个寄存器占一个 32bit 字（4 字节）起始地址
        $reg_addresses{$reg->{address}} = 1;
    }
    
    foreach my $table (@tables) {
        my $esz = memory_entry_size_words($table->{width});
        my $table_size = $table->{depth} * $esz * 4;
        my $table_end = $table->{address} + $table_size;
        # 检查表地址是否与寄存器地址冲突
        for (my $addr = $table->{address}; $addr < $table_end; $addr += 4) {
            if (exists $reg_addresses{$addr}) {
                push @errors, "Table $table->{name} address " . sprintf("0x%08X", $addr) . " conflicts with register address";
            }
        }
    }
    
    return (\@errors, \@warnings);
}

# 主函数
if (@ARGV < 1) {
    print "Usage: perl RegValidator.pl <output_file>\n";
    print "Example: perl RegValidator.pl templateReg.txt\n";
    exit(1);
}

my $output_file = $ARGV[0];

eval {
    print "Parsing file: $output_file\n";
    my ($registers_ref, $tables_ref) = parse_output_file($output_file);
    my @registers = @$registers_ref;
    my @tables = @$tables_ref;
    print "Found " . scalar(@registers) . " registers and " . scalar(@tables) . " tables\n";
    
    print "\nValidating registers...\n";
    my ($reg_errors_ref, $reg_warnings_ref) = validate_registers($registers_ref);
    my @reg_errors = @$reg_errors_ref;
    my @reg_warnings = @$reg_warnings_ref;
    
    print "Validating tables...\n";
    my ($table_errors_ref, $table_warnings_ref) = validate_tables($tables_ref);
    my @table_errors = @$table_errors_ref;
    my @table_warnings = @$table_warnings_ref;
    
    print "Validating address space...\n";
    my ($addr_errors_ref, $addr_warnings_ref) = validate_address_space($registers_ref, $tables_ref);
    my @addr_errors = @$addr_errors_ref;
    my @addr_warnings = @$addr_warnings_ref;
    
    # 汇总错误和警告
    my @all_errors = (@reg_errors, @table_errors, @addr_errors);
    my @all_warnings = (@reg_warnings, @table_warnings, @addr_warnings);
    
    # 输出结果
    if (@all_errors > 0) {
        print "\n❌ Validation FAILED: " . scalar(@all_errors) . " error(s) found\n";
        foreach my $error (@all_errors) {
            print "  ERROR: $error\n";
        }
    } else {
        print "\n✅ Validation PASSED: No errors found\n";
    }
    
    if (@all_warnings > 0) {
        print "\n⚠️  " . scalar(@all_warnings) . " warning(s):\n";
        foreach my $warning (@all_warnings) {
            print "  WARNING: $warning\n";
        }
    }
    
    if (@all_errors > 0) {
        exit(1);
    } else {
        exit(0);
    }
};

if ($@) {
    print "Error: $@\n";
    exit(1);
}