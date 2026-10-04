#!/usr/bin/env perl
# -*- coding: utf-8 -*-
# 寄存器RTL代码生成器
# 从带地址的寄存器表文件生成RTL Verilog文件

use strict;
use warnings;
use utf8;
use Getopt::Long;
use File::Basename;

# 寄存器类
package Register;
sub new {
    my ($class, $name, $address, $offset, $bit_range, $width, $type, $default_value, $description) = @_;
    my $self = {
        name => $name,
        address => $address,
        offset => $offset,
        bit_range => $bit_range,
        width => $width,
        type => uc($type),
        default_value => $default_value,  # 默认值
        description => $description,
        decode_index => undef,  # 在level0中的索引
        level0_group => undef,  # 属于哪个level0组
    };
    bless $self, $class;
    return $self;
}

# 内存字段类
package MemoryField;
sub new {
    my ($class, $name, $offset, $field_hi, $field_lo, $description) = @_;
    my $self = {
        name => $name,
        offset => $offset,
        field_hi => int($field_hi),
        field_lo => int($field_lo),
        description => $description,
    };
    bless $self, $class;
    return $self;
}

# 内存类
package Memory;
sub new {
    my ($class, $name, $address, $depth, $width, $description) = @_;
    my $self = {
        name => $name,
        address => $address,
        depth => int($depth),
        width => int($width),
        description => $description,
        fields => [],  # MemoryField数组
        decode_index => undef,  # 在level0中的索引
        level0_group => undef,  # 属于哪个level0组
        entry_size => 0,  # Entry大小（以4字节为单位）
        first_offset => 0,  # 第一个字段的offset
        last_offset => 0,   # 最后一个字段的offset
    };
    bless $self, $class;
    return $self;
}

sub add_field {
    my ($self, $field) = @_;
    push @{$self->{fields}}, $field;
    # 更新offset范围
    my $max_offset = 0;
    my $min_offset = 999999;
    for my $f (@{$self->{fields}}) {
        my $off = $f->{offset};
        $max_offset = $off if $off > $max_offset;
        $min_offset = $off if $off < $min_offset;
    }
    $self->{first_offset} = $min_offset;
    $self->{last_offset} = $max_offset;
    # entry_size应该根据width计算，而不是根据字段的offset
    # width以位为单位，转换为4字节单位：width/32
    if ($self->{width} > 0) {
        $self->{entry_size} = int(($self->{width} + 31) / 32);  # 向上取整到4字节单位
    } else {
        # 如果没有width信息，则根据字段offset计算
        $self->{entry_size} = int(($max_offset + 4) / 4);  # 以4字节为单位
    }
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
    my @registers = ();
    my @memories = ();
    
    open(my $fh, '<:encoding(utf8)', $filename) or die "Cannot open file $filename: $!\n";
    my @lines = <$fh>;
    close($fh);
    
    my $in_register_section = 0;
    my $in_memory_section = 0;
    my $in_memory_field_section = 0;
    my $current_memory = undef;
    
    for my $line (@lines) {
        chomp($line);
        my $original_line = $line;
        $line =~ s/^\s+|\s+$//g;
        
        # 跳过空行和注释行
        next if (!$line || $line =~ /^#/);
        
        # 检查是否是寄存器表头行（支持带或不带defaultValue列）
        if ($line =~ /^name\s+address\s+offset\s+bit_range\s+width\s+type\s+(defaultValue\s+)?description/i) {
            $in_register_section = 1;
            $in_memory_section = 0;
            $in_memory_field_section = 0;
            next;
        }
        
        # 检查是否是内存表头行
        if ($line =~ /^name\s+address\s+depth\s+width\s+description/i) {
            $in_register_section = 0;
            $in_memory_section = 1;
            $in_memory_field_section = 0;
            next;
        }
        
        # 检查是否是内存字段表头行
        if ($line =~ /^name\s+offset\s+fieldHi\s+fieldLo\s+description/i) {
            $in_register_section = 0;
            $in_memory_section = 0;
            $in_memory_field_section = 1;
            next;
        }
        
        # 检查是否是MemName标记（表名不限于 \w，与 RegParser 输出一致）
        if ($line =~ /^MemName:\s*(\S+)/i) {
            my $mem_name = $1;
            # 查找对应的内存
            for my $mem (@memories) {
                if ($mem->{name} eq $mem_name) {
                    $current_memory = $mem;
                    last;
                }
            }
            $in_memory_field_section = 1;
            next;
        }
        
        # 跳过分隔线
        next if ($line =~ /^#+$/);
        
        # 解析寄存器行
        if ($in_register_section) {
            my @parts = split(/\s+/, $original_line);
            if (@parts >= 7) {
                my $name = $parts[0];
                my $address_str = $parts[1];
                my $offset_str = $parts[2];
                my $bit_range = $parts[3];
                my $width = int($parts[4]);
                my $type = $parts[5];
                my $default_value = "";  # 默认值，可能为空
                my $description = "";
                
                # 检查是否有defaultValue列（第7列）
                if (@parts >= 8) {
                    $default_value = $parts[6];
                    $description = join(' ', @parts[7..$#parts]);
                } else {
                    # 兼容旧格式：没有defaultValue列
                    $description = join(' ', @parts[6..$#parts]);
                }
                
                my $address = parse_hex_address($address_str);
                if (defined $address) {
                    push @registers, Register->new($name, $address, $offset_str, $bit_range, $width, $type, $default_value, $description);
                }
            }
        }
        
        # 解析内存定义行
        if ($in_memory_section) {
            my @parts = split(/\s+/, $original_line);
            if (@parts >= 5) {
                my $name = $parts[0];
                my $address_str = $parts[1];
                my $depth = int($parts[2]);
                my $width = int($parts[3]);
                my $description = join(' ', @parts[4..$#parts]);
                
                my $address = parse_hex_address($address_str);
                if (defined $address) {
                    my $mem = Memory->new($name, $address, $depth, $width, $description);
                    push @memories, $mem;
                }
            }
        }
        
        # 解析内存字段行
        if ($in_memory_field_section && defined $current_memory) {
            my @parts = split(/\s+/, $original_line);
            if (@parts >= 5) {
                next unless $parts[1] =~ /^(0x[0-9a-fA-F]+|\d+)$/i;
                my $name = $parts[0];
                # RegParser 输出十进制 offset；无 0x 前缀时必须按十进制解析（避免 10 被当成 0x10）
                my $offset = ($parts[1] =~ /^0x/i) ? parse_hex_address($parts[1])
                    : ($parts[1] =~ /^\d+$/ ? int($parts[1]) : parse_hex_address($parts[1]));
                my $field_hi = int($parts[2]);
                my $field_lo = int($parts[3]);
                my $description = join(' ', @parts[4..$#parts]);
                
                if (defined $offset) {
                    my $field = MemoryField->new($name, $offset, $field_hi, $field_lo, $description);
                    $current_memory->add_field($field);
                }
            }
        }
    }
    
    return (\@registers, \@memories);
}

sub organize_registers_by_decode {
    my ($registers_ref, $memories_ref) = @_;
    my @registers = @$registers_ref;
    my @memories = defined $memories_ref ? @$memories_ref : ();
    
    # 按地址排序
    @registers = sort { $a->{address} <=> $b->{address} } @registers;
    @memories = sort { $a->{address} <=> $b->{address} } @memories;
    
    # 计算每个寄存器属于哪个level0组和索引
    # level0组按地址[27:6]划分（每64字节=16个4字节地址一个组）
    # 组内索引按地址[5:2]划分（每个4字节地址一个索引）
    my %level0_groups = ();
    
    for my $reg (@registers) {
        my $addr = $reg->{address};
        my $level0_group = ($addr >> 6);  # [27:6]，每64字节一个组
        my $decode_index = ($addr >> 2) & 0xF;        # [5:2]，16个地址一个索引
        
        $reg->{level0_group} = $level0_group;
        $reg->{decode_index} = $decode_index;
        
        if (!exists $level0_groups{$level0_group}) {
            $level0_groups{$level0_group} = [];
        }
        push @{$level0_groups{$level0_group}}, $reg;
    }
    
    # 处理内存：内存使用首地址来计算level0_group和decode_index
    # 内存的地址范围从首地址到首地址+depth*entry_size*4
    for my $mem (@memories) {
        my $addr = $mem->{address};
        # 计算内存覆盖的地址范围
        my $entry_size = $mem->{entry_size};
        $entry_size = 1 if $entry_size == 0;  # 默认至少1个4字节
        my $mem_size = $mem->{depth} * $entry_size * 4;  # 总字节数
        
        # 使用首地址计算level0_group和decode_index
        my $level0_group = ($addr >> 6);
        my $decode_index = ($addr >> 2) & 0xF;
        
        $mem->{level0_group} = $level0_group;
        $mem->{decode_index} = $decode_index;
        
        # 计算地址提取范围
        # 需要找到地址中用于索引Entry的位
        # 假设地址格式：base[31:N] + entry_idx[M:0] + offset[K:2]
        # 需要计算entry_idx的位宽
        my $entry_idx_bits = 0;
        my $temp = $mem->{depth} - 1;
        while ($temp > 0) {
            $entry_idx_bits++;
            $temp >>= 1;
        }
        $entry_idx_bits = 1 if $entry_idx_bits == 0;
        $mem->{entry_idx_bits} = $entry_idx_bits;
        
        # 计算offset的位宽（entry_size以4字节为单位）
        my $offset_bits = 0;
        $temp = $entry_size - 1;
        while ($temp > 0) {
            $offset_bits++;
            $temp >>= 1;
        }
        $mem->{offset_bits} = $offset_bits;
        
        # 计算地址提取位置
        # 地址格式：base[31:N] + entry_idx[M:0] + offset[K:2] + byte[1:0]
        # offset从[2:2+offset_bits-1]提取
        # entry_idx从[2+offset_bits:2+offset_bits+entry_idx_bits-1]提取
        $mem->{offset_low} = 2;
        $mem->{offset_high} = 2 + $offset_bits - 1;
        $mem->{entry_idx_low} = 2 + $offset_bits;
        $mem->{entry_idx_high} = 2 + $offset_bits + $entry_idx_bits - 1;
        
        # 计算需要比较的地址位范围（基地址部分）
        # 需要比较的位：[31:(2+offset_bits+entry_idx_bits)]
        my $addr_compare_high = 31;
        my $addr_compare_low = 2 + $offset_bits + $entry_idx_bits;
        $mem->{addr_compare_high} = $addr_compare_high;
        $mem->{addr_compare_low} = $addr_compare_low;
        my $addr_compare_width = $addr_compare_high - $addr_compare_low + 1;
        $mem->{addr_compare_width} = $addr_compare_width;
        # 计算比较值（基地址右移addr_compare_low位）
        my $addr_compare_value = $addr >> $addr_compare_low;
        $mem->{addr_compare_value} = $addr_compare_value;
    }
    
    return (\%level0_groups, \@registers, \@memories);
}


sub get_module_name {
    my ($filename) = @_;
    my $basename = basename($filename);
    $basename =~ s/\.(v|txt)$//i;  # 去掉.v或.txt后缀
    $basename =~ s/[^a-zA-Z0-9_]/_/g;
    $basename =~ s/^_+|_+$//g;
    if (!$basename) {
        $basename = "RegModule";
    }
    return $basename;
}

# 格式化长行，确保每行不超过128个字符，在合适的地方换行
sub format_long_line {
    my ($line, $indent, $max_width) = @_;
    $max_width = 128 unless defined $max_width;
    $indent = "" unless defined $indent;
    
    # 如果行已经足够短，直接返回
    if (length($line) <= $max_width) {
        return $line . "\n";
    }
    
    my $result = "";
    my $current_line = $indent;
    my $current_indent = $indent;
    
    # 按分隔符分割（|| 或 , 或 : (三元运算符)）
    # 保留分隔符，以便在换行时保留它们
    my @parts = split(/(\s*\|\|\s*|,\s*|:\s*(?=\d+'h|\d+'d|\w+))/i, $line);
    
    for my $part (@parts) {
        my $test_line = $current_line . $part;
        
        # 如果加上这个部分会超过最大宽度，需要换行
        if (length($test_line) > $max_width && length($current_line) > length($indent)) {
            $result .= $current_line . "\n";
            $current_line = $current_indent . $part;
        } else {
            $current_line = $test_line;
        }
    }
    
    # 添加最后一行
    if (length($current_line) > length($indent)) {
        $result .= $current_line;
    }
    
    return $result . "\n";
}

# 格式化端口列表，每行不超过128个字符
sub format_port_list {
    my ($ports, $indent, $max_width) = @_;
    $max_width = 128 unless defined $max_width;
    $indent = "        " unless defined $indent;
    
    my $result = "";
    my $current_line = $indent;
    
    for my $i (0..$#{$ports}) {
        my $port = $ports->[$i];
        my $separator = ($i < $#{$ports}) ? ", " : "";
        my $test_line = $current_line . $port . $separator;
        
        # 如果加上这个端口会超过最大宽度，需要换行
        if (length($test_line) > $max_width && length($current_line) > length($indent)) {
            $result .= $current_line . "\n";
            $current_line = $indent . $port . $separator;
        } else {
            $current_line = $test_line;
        }
    }
    
    if (length($current_line) > length($indent)) {
        $result .= $current_line;
    }
    
    return $result;
}

# 格式化拼接表达式，每行不超过128个字符
sub format_concat_expr {
    my ($prefix, $items, $indent, $max_width) = @_;
    $max_width = 128 unless defined $max_width;
    $indent = "    " unless defined $indent;
    
    my $result = $prefix . "{";
    my $current_line = $prefix . "{";
    # 计算换行后的缩进：prefix的长度 + 1（用于对齐 { 后的内容）
    my $line_indent_len = length($prefix) + 1;
    my $line_indent = " " x $line_indent_len;
    
    for my $i (0..$#{$items}) {
        my $item = $items->[$i];
        my $separator = ($i < $#{$items}) ? ", " : "";
        my $test_line = $current_line . $item . $separator;
        
        # 如果加上这个项会超过最大宽度，需要换行
        if (length($test_line) > $max_width && length($current_line) > length($prefix) + 1) {
            $result .= "\n" . $indent . $line_indent . $item . $separator;
            $current_line = $indent . $line_indent . $item . $separator;
        } else {
            $result .= $item . $separator;
            $current_line = $test_line;
        }
    }
    
    $result .= "}";
    return $result;
}

sub generate_rtl {
    my ($registers_ref, $level0_groups_ref, $module_name, $output_file, $memories_ref) = @_;
    my @registers = @$registers_ref;
    my %level0_groups = %$level0_groups_ref;
    my @memories = defined $memories_ref ? @$memories_ref : ();
    
    open(my $fh, '>:encoding(utf8)', $output_file) or die "Cannot open file $output_file: $!\n";
    
    # 生成文件头
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
    $year += 1900;
    $mon += 1;
    my $date_str = sprintf("%04d/%02d/%02d %02d:%02d", $year, $mon, $mday, $hour, $min);
    
    print $fh "// +FHDR----------------------------------------------------------------------------\n";
    print $fh "// Device        : Xilinx\n";
    print $fh "// Author        : Auto Generated\n";
    print $fh "// Email         : \n";
    print $fh "// Created On    : $date_str\n";
    print $fh "// File Name     : " . basename($output_file) . "\n";
    print $fh "// Description   : Auto generated register module\n";
    print $fh "//         \n";
    print $fh "// \n";
    print $fh "// ---------------------------------------------------------------------------------\n";
    print $fh "// Modification History:\n";
    print $fh "// Date         By              Version                 Change Description\n";
    print $fh "// ---------------------------------------------------------------------------------\n";
    print $fh "// $date_str   Auto Generated   1.0                     Original\n";
    print $fh "// -FHDR----------------------------------------------------------------------------\n";
    
    # 收集所有端口
    my @input_ports = ();
    my @output_ports = ();
    my %reg_port_map = ();
    
    for my $reg (@registers) {
        my $name = $reg->{name};
        my $type = $reg->{type};
        my $width = $reg->{width};
        
        # 根据width生成位宽字符串，并使用固定宽度格式化以保持对齐
        my $width_str = "";
        if ($width > 1) {
            my $width_val = $width - 1;
            $width_str = sprintf("[%d:0]", $width_val);
        }
        # 格式化位宽字符串为固定宽度（7个字符，与[31:0]对齐）
        $width_str = sprintf("%-7s", $width_str);
        
        # #region agent log
        #open(my $log_fh, '>>', 'e:\\AiScripts\\regDefine\\.cursor\\debug.log') or die "Cannot open log file: $!\n";
        my $log_data = sprintf('{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"reg_rtl_generator.pl:469","message":"Generating port with width","data":{"name":"%s","width":%d,"type":"%s","usedWidth":%d},"timestamp":%d}', $name, $width, $type, $width, time() * 1000);
        #print $log_fh $log_data . "\n";
        #close($log_fh);
        # #endregion
        
        if ($type eq 'RO' || $type eq 'RI' || $type eq 'RIWI' || $type eq 'RIW' || $type eq 'RWI') {
            push @input_ports, "input     $width_str        $name;";
            $reg_port_map{$name} = {dir => 'input', type => $type};
        }
        
        if ($type eq 'WO' || $type eq 'RW') {
            push @output_ports, "output    $width_str        $name;";
            $reg_port_map{$name} = {dir => 'output', type => $type};
        }
        
        if ($type eq 'WI' || $type eq 'RWI') {
            push @output_ports, "output    $width_str        ${name}WrData;";
        }
        
        if ($type eq 'RIWI' || $type eq 'RIW') {
            push @output_ports, "output    $width_str        ${name}WrData;";
        }
        
        if ($type eq 'WI' || $type eq 'RWI' || $type eq 'RIWI') {
            # Trigger信号：前缀 + 首字母大写化后的原始名称
            my $wr_signal = $name;
            $wr_signal =~ s/^([a-z])/uc($1)/e;
            push @output_ports, "output                  wr${wr_signal};";
        }
        
        if ($type eq 'RI' || $type eq 'RIWI' || $type eq 'RIW') {
            # Trigger信号：前缀 + 首字母大写化后的原始名称
            my $rd_signal = $name;
            $rd_signal =~ s/^([a-z])/uc($1)/e;
            push @output_ports, "output                  rd${rd_signal};";
        }
    }
    
    # 收集内存端口（不添加到@output_ports和@input_ports，避免重复声明）
    my %mem_port_map = ();
    my @mem_input_port_names = ();
    my @mem_output_port_names = ();
    for my $mem (@memories) {
        my $name = $mem->{name};
        my @fields = @{$mem->{fields}};
        $mem_port_map{$name} = {fields => \@fields};
        
        # 收集内存端口名称（用于添加到module声明）
        for my $field (@fields) {
            my $field_name = $field->{name};
            my $field_width = $field->{field_hi} - $field->{field_lo} + 1;
            my $field_width_val = $field_width - 1;
            push @mem_output_port_names, "${name}${field_name}WrData";
            push @mem_input_port_names, "${name}${field_name}RdData";
        }
        
        my $addr_bits = $mem->{entry_idx_bits};
        my $addr_bits_val = $addr_bits - 1;
        push @mem_output_port_names, "${name}Wr";
        push @mem_output_port_names, "${name}WrAddr";
        push @mem_output_port_names, "${name}Rd";
        push @mem_output_port_names, "${name}RdAddr";
        push @mem_input_port_names, "${name}RdAck";
    }
    
    
    # 生成module声明
    print $fh "module $module_name(/*autoarg*/\n";
    print $fh "        //Inputs\n";
    my @input_port_names = ("clock", "rstN", "wr", "wrAddr", "wrData", 
                            "rd", "rdAddr");
    if (@input_ports > 0) {
        # 提取端口名称：移除input关键字、位宽声明（如果有）和分号
        push @input_port_names, map { 
            my $p = $_; 
            $p =~ s/input\s+(?:\[[^\]]+\]\s+)?\s*//;  # 移除input和可选的位宽声明
            $p =~ s/;//;  # 移除分号
            $p =~ s/^\s+|\s+$//g;  # 移除首尾空白
            $p; 
        } @input_ports;
    }
    if (@mem_input_port_names > 0) {
        push @input_port_names, @mem_input_port_names;
    }
    print $fh format_port_list(\@input_port_names, "        ");
    print $fh ",\n";
    print $fh "        //Outputs\n";
    my @output_port_names = ("wrAck", "wrErr", "rdAck", "rdErr", "rdData");
    if (@output_ports > 0) {
        # 提取端口名称：移除output关键字、位宽声明（如果有）和分号
        push @output_port_names, map { 
            my $p = $_; 
            $p =~ s/output\s+(?:\[[^\]]+\]\s+)?\s*//;  # 移除output和可选的位宽声明
            $p =~ s/;//;  # 移除分号
            $p =~ s/^\s+|\s+$//g;  # 移除首尾空白
            $p; 
        } @output_ports;
    }
    if (@mem_output_port_names > 0) {
        push @output_port_names, @mem_output_port_names;
    }
    print $fh format_port_list(\@output_port_names, "        ");
    print $fh "\n);\n\n\n\n";
    
    # 生成接口声明
    print $fh "//###################################################### \n";
    print $fh "//Interface\n";
    print $fh "//###################################################### \n\n";
    
    print $fh "    input                   clock;\n";
    print $fh "    input                   rstN;\n\n";
    
    print $fh "    input                  wr;\n";
    print $fh "    input [31:0]           wrAddr;\n";
    print $fh "    input [31:0]           wrData;\n";
    print $fh "    output                 wrAck;\n";
    print $fh "    output                 wrErr;\n";
    print $fh "    \n";
    print $fh "    input                  rd;\n";
    print $fh "    input [31:0]           rdAddr;\n";
    print $fh "    output                 rdAck;\n";
    print $fh "    output                 rdErr;\n";
    print $fh "    output  [31:0]         rdData;\n\n";
    
    # 生成寄存器端口
    if (@input_ports > 0 || @output_ports > 0) {
        print $fh "    //RO WO ,RW ,RI ,WI ,RWI,RIWI\n\n";
        
        for my $port (@input_ports) {
            print $fh "    $port\n";
        }
        
        if (@input_ports > 0 && @output_ports > 0) {
            print $fh "\n";
        }
        
        for my $port (@output_ports) {
            print $fh "    $port\n";
        }
        
        print $fh "\n";
    }
    
    # 生成内存端口
    if (@memories > 0) {
        print $fh "    //Memory interfaces\n\n";
        for my $mem (@memories) {
            my $name = $mem->{name};
            my @fields = @{$mem->{fields}};
            
            # 字段端口
            for my $field (@fields) {
                my $field_name = $field->{name};
                my $field_width = $field->{field_hi} - $field->{field_lo} + 1;
                my $field_width_val = $field_width - 1;
                print $fh "    output    [$field_width_val:0]        ${name}${field_name}WrData;\n";
                print $fh "    input     [$field_width_val:0]        ${name}${field_name}RdData;\n";
            }
            
            # 控制信号
            my $addr_bits = $mem->{entry_idx_bits};
            my $addr_bits_val = $addr_bits - 1;
            print $fh "    output                  ${name}Wr;\n";
            print $fh "    output    [$addr_bits_val:0]          ${name}WrAddr;\n";
            print $fh "    output                  ${name}Rd;\n";
            print $fh "    output    [$addr_bits_val:0]          ${name}RdAddr;\n";
            print $fh "    input                    ${name}RdAck;\n";
            print $fh "\n";
        }
    }
    
    # 生成内部信号
    print $fh "//###################################################### \n";
    print $fh "//Value\n";
    print $fh "//###################################################### \n";
    
    print $fh "wire  [31:0]  rdAddrErrData;\n";
    print $fh "reg   [31:0]  rdData;\n";
    print $fh "reg           rdAck;\n";
    print $fh "reg           rdErr;\n";
    
    # 声明 rdDataSel（用于单组情况的数据选择）
    # 计算所需的位宽：需要编码 1个组hit + N个内存 + 1个default = N+2 种情况
    if (@memories > 0) {
        my $num_mems = scalar(@memories);
        my $num_sel_bits = int(log($num_mems + 2) / log(2)) + 1;
        $num_sel_bits = 2 if $num_sel_bits < 2;  # 至少2位
        my $num_sel_bits_val = $num_sel_bits - 1;  # 位宽值（用于 [N:0] 格式）
        print $fh "reg   [$num_sel_bits_val:0]   rdDataSel;\n";
    }
    
    # 生成trigger信号
    for my $reg (@registers) {
        my $type = $reg->{type};
        my $name = $reg->{name};
        
        if ($type eq 'RI' || $type eq 'RIWI' || $type eq 'RIW') {
            my $rd_signal = $name;
            $rd_signal =~ s/^([a-z])/uc($1)/e;
            print $fh "reg           rd${rd_signal};\n";
        }
        if ($type eq 'WI' || $type eq 'RWI' || $type eq 'RIWI') {
            my $wr_signal = $name;
            $wr_signal =~ s/^([a-z])/uc($1)/e;
            print $fh "reg           wr${wr_signal};\n";
        }
    }
    
    # 生成寄存器存储
    for my $reg (@registers) {
        my $type = $reg->{type};
        my $name = $reg->{name};
        my $width = $reg->{width};
        
        # 根据width生成位宽字符串，并使用固定宽度格式化以保持对齐
        my $width_str = "";
        if ($width > 1) {
            my $width_val = $width - 1;
            $width_str = sprintf("[%d:0]", $width_val);
        }
        # 格式化位宽字符串为固定宽度（7个字符，与[31:0]对齐）
        $width_str = sprintf("%-7s", $width_str);
        
        # #region agent log
        ##open(my $log_fh, '>>', 'e:\\AiScripts\\regDefine\\.cursor\\debug.log') or die "Cannot open log file: $!\n";
        my $log_data = sprintf('{"sessionId":"debug-session","runId":"run1","hypothesisId":"C","location":"reg_rtl_generator.pl:653","message":"Generating register declaration with width","data":{"name":"%s","width":%d,"type":"%s","usedWidth":%d},"timestamp":%d}', $name, $width, $type, $width, time() * 1000);
        #print $log_fh $log_data . "\n";
        #close($log_fh);
        # #endregion
        
        if ($type eq 'WO' || $type eq 'RW') {
            print $fh "reg  $width_str   $name;\n";
        }
        if ($type eq 'WI' || $type eq 'RWI') {
            print $fh "reg  $width_str   ${name}WrData;\n";
        }
        if ($type eq 'RIWI' || $type eq 'RIW') {
            print $fh "reg  $width_str   ${name}WrData;\n";
        }
    }
    
    # 生成内存相关的内部信号
    for my $mem (@memories) {
        my $name = $mem->{name};
        my @fields = @{$mem->{fields}};
        my $group_id = $mem->{level0_group};
        my $decode_index = $mem->{decode_index};
        my $addr_bits = $mem->{entry_idx_bits};
        my $offset_bits = $mem->{offset_bits};
        
        # 为每个字段生成WrData寄存器
        for my $field (@fields) {
            my $field_name = $field->{name};
            my $field_width = $field->{field_hi} - $field->{field_lo} + 1;
            my $field_width_val = $field_width - 1;
            print $fh "reg  [$field_width_val:0]   ${name}${field_name}WrData;\n";
        }
        
        # 生成内存的hit和decode信号
        print $fh "reg           ${name}RdHit;\n";
        print $fh "reg           ${name}WrHit;\n";
        if ($offset_bits > 0) {
            my $offset_bits_val = $offset_bits - 1;
            # 读取和写入使用不同的地址，需要分开的信号
            print $fh "wire  [$offset_bits_val:0]   ${name}RdOffsetDecode;\n";
            print $fh "wire  [$offset_bits_val:0]   ${name}WrOffsetDecode;\n";
            # RdDataTemp在always块中被赋值，需要是reg型
            print $fh "reg   [31:0]   ${name}RdDataTemp;\n";
            # 内存读取错误信号（当offset无效时）
            print $fh "wire          ${name}RdErr;\n";
            # 内存读取HitReal信号（Hit有效且无错误）
            print $fh "wire          ${name}RdHitReal;\n";
            # 内存写入错误信号（当offset无效时）
            print $fh "wire          ${name}WrErr;\n";
        }
        print $fh "wire          ${name}RdInt;\n";
        print $fh "wire          ${name}WrInt;\n";
        my $addr_bits_val = $addr_bits - 1;
        print $fh "wire  [$addr_bits_val:0]   ${name}RdAddrInt;\n";
        print $fh "wire  [$addr_bits_val:0]   ${name}WrAddrInt;\n";
        # memWr和memWrAddr是output端口，但在always块中被赋值，需要定义为reg类型
        print $fh "reg           ${name}Wr;\n";
        print $fh "reg  [$addr_bits_val:0]   ${name}WrAddr;\n";
    }
    
    # 收集所有有内存的level0组（在Value声明之前，用于信号声明）
    my %all_groups_for_decl = %level0_groups;
    for my $mem (@memories) {
        my $group_id = $mem->{level0_group};
        if (!exists $all_groups_for_decl{$group_id}) {
            $all_groups_for_decl{$group_id} = [];
        }
    }
    
    # 收集有可写寄存器的组（在Value声明之前，用于信号声明）
    my %groups_with_writable = ();
    for my $group_id (keys %level0_groups) {
        my $group_regs = $level0_groups{$group_id};
        for my $reg (@$group_regs) {
            my $type = $reg->{type};
            if ($type eq 'WO' || $type eq 'RW' || $type eq 'WI' || $type eq 'RWI' || $type eq 'RIWI' || $type eq 'RIW') {
                $groups_with_writable{$group_id} = 1;
                last;
            }
        }
    }
    
    # 为每个level0组生成decode信号（只包括有寄存器的组，不包括只有内存的组）
    my $group_count = 0;
    for my $group_id (sort { $a <=> $b } keys %all_groups_for_decl) {
        # 只对有寄存器的组生成这些信号
        if (exists $level0_groups{$group_id} && @{$level0_groups{$group_id}} > 0) {
            print $fh "wire  [3:0]   rdDecodeLevel0_$group_id;\n";
            print $fh "reg   [31:0]  rdDataLevel0_$group_id;\n";
            print $fh "reg           rdLevel0_${group_id}Err;\n";
            print $fh "reg           rdHitLevel0_$group_id;\n";
            
            print $fh "reg           wrHitLevel0_$group_id;\n";
            
            # 检查这个组是否有可写寄存器
            my $has_writable = 0;
            my $group_regs = $level0_groups{$group_id};
            for my $reg (@$group_regs) {
                my $type = $reg->{type};
                if ($type eq 'WO' || $type eq 'RW' || $type eq 'WI' || $type eq 'RWI' || $type eq 'RIWI' || $type eq 'RIW') {
                    $has_writable = 1;
                    last;
                }
            }
            
            # 如果有可写寄存器，wrLevel0_XErr在always块中赋值，需要是reg型
            # 如果没有可写寄存器，wrLevel0_XErr通过assign赋值，需要是wire型
            if ($has_writable) {
                print $fh "reg           wrLevel0_${group_id}Err;\n";
            } else {
                print $fh "wire          wrLevel0_${group_id}Err;\n";
            }
        }
    }
    
    # 为有可写寄存器的组声明write decode信号
    for my $group_id (sort { $a <=> $b } keys %groups_with_writable) {
        print $fh "wire  [3:0]   wrDecodeLevel0_$group_id;\n";
    }
    
    print $fh "wire          rdHitDecode;\n";
    print $fh "reg   [31:0]  rdAddrF1;\n";
    print $fh "reg   [31:0]  wrAddrF1;\n";
    print $fh "reg   [31:0]  wrDataF1;\n";
    
    # 收集Level1及以上的多级选择结构需要的变量声明
    my $total_groups_decl = scalar keys %all_groups_for_decl;
    my @level1_declarations = ();
    
    if ($total_groups_decl > 1) {
        my @sorted_group_ids_decl = sort { $a <=> $b } keys %all_groups_for_decl;
        my @data_signals_decl = map { "rdDataLevel0_$_" } @sorted_group_ids_decl;
        my @hit_signals_list_decl = map { "rdHitLevel0_$_" } @sorted_group_ids_decl;
        
        # 生成多级选择结构需要的变量声明
        my $level_decl = 1;
        my @current_data_decl = @data_signals_decl;
        my @current_hits_decl = @hit_signals_list_decl;
        
        while (scalar(@current_data_decl) > 2) {
            my @next_data_decl = ();
            my @next_hits_decl = ();
            my $mux_idx_decl = 0;
            
            for (my $i = 0; $i < scalar(@current_data_decl) && $mux_idx_decl < 2; $i += 16) {
                my $group_size_decl = (scalar(@current_data_decl) - $i) > 16 ? 16 : (scalar(@current_data_decl) - $i);
                my $sel_name_decl = "rdSelLevel${level_decl}_${mux_idx_decl}";
                my $hit_name_decl = "rdHitLevel${level_decl}_${mux_idx_decl}";
                my $mux_name_decl = "rdDataLevel${level_decl}_${mux_idx_decl}";
                
                push @level1_declarations, "reg  [3:0]   ${sel_name_decl};";
                push @level1_declarations, "wire         ${hit_name_decl}_wire;";
                push @level1_declarations, "wire [15:0] ${sel_name_decl}_onehot;";
                push @level1_declarations, "reg  [31:0]  ${mux_name_decl}_comb;";
                push @level1_declarations, "reg  [31:0]  ${mux_name_decl};";
                push @level1_declarations, "reg         ${hit_name_decl};";
                push @level1_declarations, "reg         rdLevel${level_decl}_${mux_idx_decl}Err_comb;";
                push @level1_declarations, "reg         rdLevel${level_decl}_${mux_idx_decl}Err;";
                
                push @next_data_decl, $mux_name_decl;
                push @next_hits_decl, $hit_name_decl;
                $mux_idx_decl++;
            }
            
            @current_data_decl = @next_data_decl;
            @current_hits_decl = @next_hits_decl;
            $level_decl++;
        }
        
        # 最后一级的decode信号
        if (scalar(@current_data_decl) == 2) {
            push @level1_declarations, "wire [1:0]   rdHitLevel1_Decode;";
        }
    }
    
    # 输出Level1及以上的变量声明
    if (@level1_declarations > 0) {
        print $fh "\n";
        for my $decl (@level1_declarations) {
            print $fh "$decl\n";
        }
    }
    
    # 生成逻辑部分
    print $fh "//###################################################### \n";
    print $fh "//Logic\n";
    print $fh "//###################################################### \n\n\n";
    
    print $fh "//Rd Part\n\n";
    print $fh "assign rdAddrErrData = 32'heef55fee;\n\n";
    
    # 为每个内存生成读取和写入hit信号（将在地址flop之后生成）
    
    # 地址和数据flop
    print $fh "always\@(posedge clock or negedge rstN)begin\n";
    print $fh "    if(!rstN)begin\n";
    print $fh "        rdAddrF1 <= 32'h0;\n";
    print $fh "        wrAddrF1 <= 32'h0;\n";
    print $fh "        wrDataF1 <= 32'h0;\n";
    # 只为有寄存器的组初始化read hit信号
    for my $group_id (sort { $a <=> $b } keys %all_groups_for_decl) {
        if (exists $level0_groups{$group_id} && @{$level0_groups{$group_id}} > 0) {
            print $fh "        rdHitLevel0_$group_id <= 1'd0;\n";
        }
    }
    # 初始化内存的read hit信号
    for my $mem (@memories) {
        my $name = $mem->{name};
        print $fh "        ${name}RdHit <= 1'd0;\n";
    }
    print $fh "    end\n";
    print $fh "    else begin\n";
    print $fh "        rdAddrF1 <= rdAddr;\n";
    print $fh "        wrAddrF1 <= wrAddr;\n";
    print $fh "        wrDataF1 <= wrData;\n";
    
        # 生成read hit信号
    # 首先为寄存器生成level0 hit信号（使用地址[31:6]）
    for my $group_id (sort { $a <=> $b } keys %all_groups_for_decl) {
        # 检查这个组是否有寄存器（不是只有内存）
        if (exists $level0_groups{$group_id} && @{$level0_groups{$group_id}} > 0) {
            my $group_addr = ($group_id << 6);
            # 计算需要的位宽：最大地址组ID的位数
            my $max_group = (sort { $b <=> $a } keys %all_groups_for_decl)[0];
            my $bits_needed = length(sprintf("%b", $max_group));
            if ($bits_needed < 1) { $bits_needed = 1; }
            my $addr_check = sprintf("((rdAddr[31:6] == %d'h%x)", 26, $group_id);
            
            print $fh "        rdHitLevel0_$group_id <= rd && $addr_check);\n";
        }
    }
    
    # 为每个内存生成单独的read hit信号（使用基地址比较）
    for my $mem (@memories) {
        my $name = $mem->{name};
        my $addr_compare_high = $mem->{addr_compare_high};
        my $addr_compare_low = $mem->{addr_compare_low};
        my $addr_compare_width = $mem->{addr_compare_width};
        my $addr_compare_value = $mem->{addr_compare_value};
        print $fh "        ${name}RdHit <= rd && (rdAddr[$addr_compare_high:$addr_compare_low] == ${addr_compare_width}'h" . sprintf("%x", $addr_compare_value) . ");\n";
    }
    
    print $fh "    end\n";
    print $fh "end\n\n";
    
    # 内存的hit信号已经通过rdHitLevel0_X和wrHitLevel0_X实现，不需要单独生成
    
    # 收集所有有内存的level0组（包括只有内存没有寄存器的组）
    my %all_groups = %level0_groups;
    for my $mem (@memories) {
        my $group_id = $mem->{level0_group};
        if (!exists $all_groups{$group_id}) {
            $all_groups{$group_id} = [];
        }
    }
    
    # 为每个level0组生成decode逻辑（只包括有寄存器的组）
    for my $group_id (sort { $a <=> $b } keys %all_groups) {
        # 跳过只有内存没有寄存器的组
        if (!exists $level0_groups{$group_id} || @{$level0_groups{$group_id}} == 0) {
            next;
        }
        
        my $group_regs = $level0_groups{$group_id};
        
        # 收集该组中的所有内存（用于在case语句中添加内存的decode_index分支）
        my @group_mems = ();
        for my $mem (@memories) {
            if ($mem->{level0_group} == $group_id) {
                push @group_mems, $mem;
            }
        }
        
        print $fh "assign rdDecodeLevel0_$group_id = rdAddrF1[5:2];\n";
        print $fh "always\@(*) begin\n";
        print $fh "    rdLevel0_${group_id}Err = 1'd0;\n";
        print $fh "    case(rdDecodeLevel0_$group_id)\n";
        
        # 创建decode映射，只包含可读的寄存器
        my %decode_map = ();
        for my $reg (@$group_regs) {
            my $idx = $reg->{decode_index};
            my $type = $reg->{type};
            # 只处理可读的寄存器类型
            if ($type eq 'RO' || $type eq 'RI' || $type eq 'RIWI' || $type eq 'RIW' || $type eq 'RW' || $type eq 'RWI') {
                $decode_map{$idx} = {type => 'reg', obj => $reg};
            }
        }
        
        # 为内存添加decode映射
        for my $mem (@group_mems) {
            my $idx = $mem->{decode_index};
            my $offset_bits = $mem->{offset_bits};
            if ($offset_bits == 0) {
                # 没有offset的内存，在case语句中添加分支
                $decode_map{$idx} = {type => 'mem_no_offset', obj => $mem};
            } else {
                # 有offset的内存，在case语句中添加分支引用临时信号
                $decode_map{$idx} = {type => 'mem_with_offset', obj => $mem};
            }
        }
        
        # 生成所有case分支（包括寄存器和没有offset的内存）
        for my $idx (sort { $a <=> $b } keys %decode_map) {
            my $entry = $decode_map{$idx};
            if ($entry->{type} eq 'reg') {
                my $reg = $entry->{obj};
                my $name = $reg->{name};
                print $fh "        4'd$idx:rdDataLevel0_$group_id = $name;\n";
            } elsif ($entry->{type} eq 'mem_no_offset') {
                my $mem = $entry->{obj};
                my $name = $mem->{name};
                my @fields = @{$mem->{fields}};
                # 生成内存数据的拼接表达式
                @fields = sort { $a->{field_lo} <=> $b->{field_lo} } @fields;
                my @concat_parts = ();
                my $last_bit = -1;
                
                for my $field (@fields) {
                    my $field_name = $field->{name};
                    my $field_lo = $field->{field_lo};
                    my $field_hi = $field->{field_hi};
                    
                    if ($last_bit >= 0 && $field_lo > $last_bit + 1) {
                        my $gap_bits = $field_lo - $last_bit - 1;
                        push @concat_parts, "${gap_bits}'d0";
                    }
                    
                    push @concat_parts, "${name}${field_name}RdData";
                    $last_bit = $field_hi;
                }
                
                my $total_bits = $last_bit + 1;
                if ($total_bits < 32) {
                    my $pad_bits = 32 - $total_bits;
                    push @concat_parts, "${pad_bits}'d0";
                }
                
                my $concat_expr = "{";
                for (my $i = @concat_parts - 1; $i >= 0; $i--) {
                    $concat_expr .= $concat_parts[$i];
                    $concat_expr .= ", " if $i > 0;
                }
                $concat_expr .= "}";
                
                print $fh "        4'd$idx:rdDataLevel0_$group_id = $concat_expr;\n";
            } elsif ($entry->{type} eq 'mem_with_offset') {
                my $mem = $entry->{obj};
                my $name = $mem->{name};
                # 有offset的内存，引用临时信号
                print $fh "        4'd$idx:rdDataLevel0_$group_id = ${name}RdDataTemp;\n";
            }
        }
        
        # 所有其他情况（不可读或不存在）都合并到default中
        print $fh "        default:begin \n";
        print $fh "            rdDataLevel0_$group_id = rdAddrErrData;\n";
        print $fh "            rdLevel0_${group_id}Err = rdHitLevel0_$group_id;\n";
        print $fh "        end\n";
        print $fh "    endcase\n";
        print $fh "end\n";
        
        # 生成read trigger逻辑（只有存在寄存器时才生成）
        my @rd_trigger_regs = ();
        if (@$group_regs > 0) {
            for my $reg (@$group_regs) {
                my $type = $reg->{type};
                if ($type eq 'RI' || $type eq 'RIWI' || $type eq 'RIW') {
                    push @rd_trigger_regs, $reg;
                }
            }
        }
        
        if (@rd_trigger_regs > 0) {
            print $fh "always\@(*) begin\n";
            for my $reg (@rd_trigger_regs) {
                my $rd_signal = $reg->{name};
                $rd_signal =~ s/^([a-z])/uc($1)/e;
                print $fh "    rd${rd_signal}         = 1'd0;\n";
            }
            print $fh "    case(rdDecodeLevel0_$group_id)\n";
            for my $reg (@rd_trigger_regs) {
                my $type = $reg->{type};
                my $idx = $reg->{decode_index};
                my $rd_signal = $reg->{name};
                $rd_signal =~ s/^([a-z])/uc($1)/e;
                print $fh "        4'd$idx:rd${rd_signal}         = rdHitLevel0_$group_id;\n";
            }
            print $fh "        default:;\n";
            print $fh "    endcase\n";
            print $fh "end\n\n";
        }
    }
    
    # 为每个内存生成读取逻辑
    for my $mem (@memories) {
        my $name = $mem->{name};
        my @fields = @{$mem->{fields}};
        my $group_id = $mem->{level0_group};
        my $decode_index = $mem->{decode_index};
        my $offset_bits = $mem->{offset_bits};
        my $entry_idx_bits = $mem->{entry_idx_bits};
        my $entry_idx_low = $mem->{entry_idx_low};
        my $entry_idx_high = $mem->{entry_idx_high};
        my $offset_low = $mem->{offset_low};
        my $offset_high = $mem->{offset_high};
        my $first_offset = $mem->{first_offset};
        my $last_offset = $mem->{last_offset};
        
        # 对于没有offset的内存，已经在寄存器case语句中处理，不需要生成单独的always块
        # 只处理有offset的内存
        if ($offset_bits > 0) {
            # 生成读取decode信号（临时信号已在Value部分声明）
            print $fh "assign ${name}RdOffsetDecode = rdAddrF1[$offset_high:$offset_low];\n";
            
            # 生成读取数据选择逻辑（赋值给临时信号）
            # 根据offset选择要读取的字段并拼接
            # 为每个可能的offset值生成case分支
            my %offset_map = ();
            for my $field (@fields) {
                my $off = $field->{offset};
                $offset_map{$off} = [] unless exists $offset_map{$off};
                push @{$offset_map{$off}}, $field;
            }
            
            my @sorted_offsets = sort { $a <=> $b } keys %offset_map;
            my $first_offset_data_expr = "";  # 保存最低偏移的数据表达式
            
            # 先计算最低偏移的数据表达式
            if (@sorted_offsets > 0) {
                my $off = $sorted_offsets[0];
                my @field_list = @{$offset_map{$off}};
                
                # 按field_lo排序字段（从低到高）
                @field_list = sort { $a->{field_lo} <=> $b->{field_lo} } @field_list;
                
                # 拼接字段：按照field_hi和field_lo的位置拼接
                my @concat_parts = ();
                my $last_bit = -1;
                
                for my $field (@field_list) {
                    my $field_name = $field->{name};
                    my $field_lo = $field->{field_lo};
                    my $field_hi = $field->{field_hi};
                    
                    # 如果字段之间有间隙，需要补0
                    if ($last_bit >= 0 && $field_lo > $last_bit + 1) {
                        my $gap_bits = $field_lo - $last_bit - 1;
                        push @concat_parts, "${gap_bits}'d0";
                    }
                    
                    push @concat_parts, "${name}${field_name}RdData";
                    $last_bit = $field_hi;
                }
                
                # 如果总位数小于32，需要在最高位补0
                my $total_bits = $last_bit + 1;
                if ($total_bits < 32) {
                    my $pad_bits = 32 - $total_bits;
                    push @concat_parts, "${pad_bits}'d0";
                }
                
                # 生成拼接表达式（从高位到低位）
                $first_offset_data_expr = "{";
                for (my $i = @concat_parts - 1; $i >= 0; $i--) {
                    $first_offset_data_expr .= $concat_parts[$i];
                    $first_offset_data_expr .= ", " if $i > 0;
                }
                $first_offset_data_expr .= "}";
            }
            
            # 生成always块，在case前添加if判断
            print $fh "always\@(*) begin\n";
            if ($first_offset_data_expr ne "") {
                print $fh "    if(${name}RdAck)begin\n";
                print $fh "        ${name}RdDataTemp = $first_offset_data_expr;\n";
                print $fh "    end\n";
                print $fh "    else begin\n";
            }
            print $fh "        case(${name}RdOffsetDecode)\n";
            
            for my $off (@sorted_offsets) {
                # offset是字节偏移，OffsetDecode从地址[offset_high:offset_low]提取
                # OffsetDecode的值直接对应offset的值（offset就是用于匹配的值）
                my $off_val = $off;
                my @field_list = @{$offset_map{$off}};
                
                # 按field_lo排序字段（从低到高）
                @field_list = sort { $a->{field_lo} <=> $b->{field_lo} } @field_list;
                
                # 拼接字段：按照field_hi和field_lo的位置拼接
                my @concat_parts = ();
                my $last_bit = -1;
                
                for my $field (@field_list) {
                    my $field_name = $field->{name};
                    my $field_lo = $field->{field_lo};
                    my $field_hi = $field->{field_hi};
                    
                    # 如果字段之间有间隙，需要补0
                    if ($last_bit >= 0 && $field_lo > $last_bit + 1) {
                        my $gap_bits = $field_lo - $last_bit - 1;
                        push @concat_parts, "${gap_bits}'d0";
                    }
                    
                    push @concat_parts, "${name}${field_name}RdData";
                    $last_bit = $field_hi;
                }
                
                # 如果总位数小于32，需要在最高位补0
                my $total_bits = $last_bit + 1;
                if ($total_bits < 32) {
                    my $pad_bits = 32 - $total_bits;
                    push @concat_parts, "${pad_bits}'d0";
                }
                
                # 生成拼接表达式（从高位到低位）
                my $concat_expr = "{";
                for (my $i = @concat_parts - 1; $i >= 0; $i--) {
                    $concat_expr .= $concat_parts[$i];
                    $concat_expr .= ", " if $i > 0;
                }
                $concat_expr .= "}";
                
                print $fh "            ${offset_bits}'d$off_val:${name}RdDataTemp = $concat_expr;\n";
            }
            
            # default情况：返回错误数据
            print $fh "            default:${name}RdDataTemp = rdAddrErrData;\n";
            print $fh "        endcase\n";
            if ($first_offset_data_expr ne "") {
                print $fh "    end\n";
            }
            print $fh "end\n\n";
            
            # 生成内存读取错误信号的赋值（变量已在Value部分声明）
            if (@sorted_offsets > 0) {
                my @valid_conditions = ();
                for my $off (@sorted_offsets) {
                    push @valid_conditions, "${name}RdOffsetDecode == ${offset_bits}'d$off";
                }
                print $fh "assign ${name}RdErr = ${name}RdHit && !(" . join(" || ", @valid_conditions) . ");\n";
            } else {
                print $fh "assign ${name}RdErr = 1'd0;\n";
            }
            # 生成memRdHitReal信号（变量已在Value部分声明）
            print $fh "assign ${name}RdHitReal = ${name}RdHit && !${name}RdErr;\n\n";
        }
        
        # 生成memRd和memRdAddr信号
        # memRd在读取Entry的第一个地址时有效
        # 对于内存，使用单独的hit信号，不需要rdDecodeLevel0_X条件
        if ($offset_bits > 0) {
            # offset是字节偏移，RdOffsetDecode的值直接对应offset的值
            my $first_offset_val = $first_offset;
            print $fh "assign ${name}RdInt = ${name}RdHit && (${name}RdOffsetDecode == ${offset_bits}'d$first_offset_val);\n";
        } else {
            print $fh "assign ${name}RdInt = ${name}RdHit;\n";
        }
        print $fh "assign ${name}RdAddrInt = rdAddrF1[$entry_idx_high:$entry_idx_low];\n";
        print $fh "assign ${name}Rd = ${name}RdInt;\n";
        print $fh "assign ${name}RdAddr = ${name}RdAddrInt;\n\n";
        
        # 将内存添加到level0组的数据选择中（如果该组还没有数据）
        # 注意：内存应该有自己的level0组，或者添加到现有的组中
        # 这里假设内存有自己独立的level0组
        if (!exists $level0_groups{$group_id}) {
            $level0_groups{$group_id} = [];
        }
    }
    
    # 生成顶层read ack和err（将在多级选择结构后生成，使用Level1信号）
    
    # 生成read data mux - 多级16选1结构
    # 只包含有寄存器的组（不包括只有内存的组）
    my @groups_with_regs = sort { $a <=> $b } grep { exists $level0_groups{$_} && @{$level0_groups{$_}} > 0 } keys %all_groups_for_decl;
    my $total_groups = scalar @groups_with_regs;
    if ($total_groups > 1) {
        my @sorted_group_ids = @groups_with_regs;
        my @data_signals = map { "rdDataLevel0_$_" } @sorted_group_ids;
        my @hit_signals_list = map { "rdHitLevel0_$_" } @sorted_group_ids;
        my @err_signals_list = map { "rdLevel0_${_}Err" } @sorted_group_ids;
        
        # 生成多级选择结构
        my $level = 1;  # 从Level1开始
        my @current_data = @data_signals;
        my @current_hits = @hit_signals_list;
        my @current_errs = @err_signals_list;
        my @current_indices = (0..($total_groups-1));
        
        while (scalar(@current_data) > 2) {
            my @next_data = ();
            my @next_hits = ();
            my @next_errs = ();
            my @next_indices = ();
            my $mux_idx = 0;
            
            # 每16个一组进行16选1，最多两个16选1
            for (my $i = 0; $i < scalar(@current_data) && $mux_idx < 2; $i += 16) {
                my $group_size = (scalar(@current_data) - $i) > 16 ? 16 : (scalar(@current_data) - $i);
                my $mux_name = "rdDataLevel${level}_${mux_idx}";
                my $sel_name = "rdSelLevel${level}_${mux_idx}";
                my $hit_name = "rdHitLevel${level}_${mux_idx}";
                
                # 生成选择信号：从hit信号的one-hot编码中提取（优先级编码）
                # 变量已在Value部分声明，这里只生成赋值逻辑
                my $hit_wire = "${hit_name}_wire";
                # 使用case语句进行one-hot到binary的转换（带优先级）
                # onehot编码：先打印多个0（高位），然后有效数据从后到前（低位）
                my @hit_list = ();
                # 先计算需要补多少个0（高位补0）
                my $num_zeros = 16 - $group_size;
                # 先push多个0到高位
                for (my $j = 0; $j < $num_zeros; $j++) {
                    push @hit_list, "1'b0";
                }
                # 然后对于有效数据，从后到前进行打印输出（从索引$group_size-1到0）
                for (my $j = $group_size - 1; $j >= 0; $j--) {
                    push @hit_list, $current_hits[$i+$j];
                }
                my $onehot_expr = format_concat_expr("assign ${sel_name}_onehot = ", \@hit_list, "    ", 128);
                print $fh $onehot_expr . ";\n";
                print $fh "assign ${hit_wire} = |${sel_name}_onehot;\n";
                # 使用case语句将one-hot转换为binary（16->4转码）
                print $fh "always\@(*) begin\n";
                print $fh "    case(${sel_name}_onehot)\n";
                # 从低位到高位，使用16'h1, 16'h2, 16'h4这样的格式
                for (my $j = 0; $j < 16; $j++) {
                    my $hex_val = sprintf("%x", $j);
                    my $onehot_val = 1 << $j;
                    my $hex_onehot = sprintf("16'h%x", $onehot_val);
                    if ($j < $group_size) {
                        print $fh "        ${hex_onehot}:${sel_name} = 4'h$hex_val;\n";
                    }
                }
                print $fh "        default:${sel_name} = 4'h0;\n";
                print $fh "    endcase\n";
                print $fh "end\n";
                
                # 生成16选1的数据选择（使用临时comb名称）
                # 变量已在Value部分声明，这里只生成逻辑
                my $mux_comb = "${mux_name}_comb";
                print $fh "always\@(*) begin\n";
                print $fh "    case(${sel_name})\n";
                for (my $j = 0; $j < $group_size; $j++) {
                    my $hex_val = sprintf("%x", $j);
                    print $fh "        4'h$hex_val:${mux_comb} = $current_data[$i+$j];\n";
                }
                print $fh "        default:${mux_comb} = rdAddrErrData;\n";
                print $fh "    endcase\n";
                print $fh "end\n";
                
                # 生成16选1的错误信号选择
                my $err_comb = "rdLevel${level}_${mux_idx}Err_comb";
                my $err_name = "rdLevel${level}_${mux_idx}Err";
                print $fh "always\@(*) begin\n";
                print $fh "    case(${sel_name})\n";
                for (my $j = 0; $j < $group_size; $j++) {
                    my $hex_val = sprintf("%x", $j);
                    print $fh "        4'h$hex_val:${err_comb} = $current_errs[$i+$j];\n";
                }
                print $fh "        default:${err_comb} = 1'd0;\n";
                print $fh "    endcase\n";
                print $fh "end\n";
                
                # 插入flop - 使用Level1_XX命名
                # 变量已在Value部分声明，这里只生成逻辑
                my $mux_f1 = "rdDataLevel${level}_${mux_idx}";
                my $hit_f1 = "rdHitLevel${level}_${mux_idx}";
                print $fh "always\@(posedge clock or negedge rstN)begin\n";
                print $fh "    if(!rstN)begin\n";
                print $fh "        ${mux_f1} <= 32'h0;\n";
                print $fh "        ${hit_f1} <= 1'd0;\n";
                print $fh "        ${err_name} <= 1'd0;\n";
                print $fh "    end\n";
                print $fh "    else begin\n";
                print $fh "        ${mux_f1} <= ${mux_comb};\n";
                print $fh "        ${hit_f1} <= ${hit_wire};\n";
                print $fh "        ${err_name} <= ${err_comb};\n";
                print $fh "    end\n";
                print $fh "end\n\n";
                
                push @next_data, $mux_f1;
                push @next_hits, $hit_f1;
                push @next_errs, $err_name;
                push @next_indices, $mux_idx;
                $mux_idx++;
            }
            
            @current_data = @next_data;
            @current_hits = @next_hits;
            @current_errs = @next_errs;
            @current_indices = @next_indices;
            $level++;
        }
        
        # 最后一级：使用case语句，case的是次级Hit的拼接（Level1的Hit信号）
        if (scalar(@current_data) == 2) {
            my $hit_width = scalar(@current_hits) - 1;
            my $hit_decode_name = "rdHitLevel1_Decode";
            # 变量已在Value部分声明，这里只生成赋值逻辑
            my @hit_list_reverse = reverse @current_hits;
            my $hit_decode_expr = format_concat_expr("assign ${hit_decode_name} = ", \@hit_list_reverse, "    ", 128);
            print $fh $hit_decode_expr . ";\n";
            print $fh "always\@(*) begin\n";
            print $fh "    case(${hit_decode_name})\n";
            # 计算十六进制位数
            my $hex_width = int(($hit_width + 3) / 4);
            for (my $i = 0; $i < scalar(@current_hits); $i++) {
                my $val = 1 << $i;
                my $hex_val = sprintf("%x", $val);
                my $hex_str = sprintf("%*s", $hex_width, $hex_val);
                $hex_str =~ s/ /0/g;
                print $fh "        " . scalar(@current_hits) . "'h" . $hex_str . ":rdData = $current_data[$i];\n";
            }
            # default分支需要处理内存读取
            # 使用memRdAck||memRdHitReal来选择内存数据，HitReal表示Hit有效且无错误
            if (@memories > 0) {
                my @mem_conditions = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    push @mem_conditions, "(${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : ";
                }
                # 最后加上rdAddrErrData作为最终的默认值
                my $default_expr = join("", @mem_conditions) . "rdAddrErrData";
                # 如果只有一个内存，简化表达式
                if (@memories == 1) {
                    my $mem_name = $memories[0]->{name};
                    print $fh "        default:rdData = (${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : rdAddrErrData;\n";
                } else {
                    # 多个内存时使用嵌套三元运算符
                    print $fh "        default:rdData = " . $default_expr . ";\n";
                }
            } else {
                print $fh "        default:rdData = rdAddrErrData;\n";
            }
            print $fh "    endcase\n";
            print $fh "end\n\n";
            
            # 生成Level1的ack和err信号（使用case语句，参照rdData的方式）
            # 需要包含内存的ack信号
            # 使用之前已声明的变量：$hit_decode_name, $hit_width, $hex_width
            
            # 收集所有内存的ack信号表达式（根据TestReg.v:210的格式）
            my @mem_ack_exprs = ();
            for my $mem (@memories) {
                my $mem_name = $mem->{name};
                push @mem_ack_exprs, "${mem_name}RdAck || (${mem_name}RdHit && !${mem_name}Rd)";
            }
            
            print $fh "always\@(*) begin\n";
            print $fh "    case(${hit_decode_name})\n";
            for (my $i = 0; $i < scalar(@current_hits); $i++) {
                my $val = 1 << $i;
                my $hex_val = sprintf("%x", $val);
                my $hex_str = sprintf("%*s", $hex_width, $hex_val);
                $hex_str =~ s/ /0/g;
                print $fh "        " . scalar(@current_hits) . "'h" . $hex_str . ":rdAck = 1'd1;\n";
            }
            if (@mem_ack_exprs > 0) {
                my $default_line = "        default:rdAck = " . join(" || ", @mem_ack_exprs) . ";";
                print $fh format_long_line($default_line, "        ", 128);
            } else {
                print $fh "        default:rdAck = 1'd0;\n";
            }
            print $fh "    endcase\n";
            print $fh "end\n";
            
            print $fh "always\@(*) begin\n";
            print $fh "    case(${hit_decode_name})\n";
            for (my $i = 0; $i < scalar(@current_errs); $i++) {
                my $val = 1 << $i;
                my $hex_val = sprintf("%x", $val);
                my $hex_str = sprintf("%*s", $hex_width, $hex_val);
                $hex_str =~ s/ /0/g;
                print $fh "        " . scalar(@current_errs) . "'h" . $hex_str . ":rdErr = $current_errs[$i];\n";
            }
            # default分支需要包含内存读取错误
            my @mem_err_signals = ();
            for my $mem (@memories) {
                my $mem_name = $mem->{name};
                push @mem_err_signals, "${mem_name}RdErr";
            }
            if (@mem_err_signals > 0) {
                my $err_expr = join(" || ", @mem_err_signals);
                print $fh "        default:rdErr = $err_expr;\n";
            } else {
                print $fh "        default:rdErr = 1'd0;\n";
            }
            print $fh "    endcase\n";
            print $fh "end\n\n";
        } elsif (scalar(@current_data) == 1) {
            # 单组情况也需要处理内存读取
            if (@memories > 0) {
                # 使用case语句进行数据选择，先使用if-else构建优先级编码的选择信号
                my $num_mems = scalar(@memories);
                my $num_sel_bits = int(log($num_mems + 2) / log(2)) + 1;
                $num_sel_bits = 2 if $num_sel_bits < 2;  # 至少2位
                # rdDataSel 已在Value部分声明，这里不再声明
                # 使用always块和if-else构建选择信号（避免三元运算符）
                print $fh "always\@(*) begin\n";
                # 优先级1：检查组hit信号
                print $fh "    if(${current_hits[0]}) begin\n";
                print $fh "        rdDataSel = ${num_sel_bits}'d0;\n";
                print $fh "    end\n";
                # 优先级2：按顺序检查每个内存，使用else if
                for (my $mem_idx = 0; $mem_idx < $num_mems; $mem_idx++) {
                    my $mem = $memories[$mem_idx];
                    my $mem_name = $mem->{name};
                    print $fh "    else if(${mem_name}RdAck || ${mem_name}RdHitReal) begin\n";
                    print $fh "        rdDataSel = ${num_sel_bits}'d" . ($mem_idx + 1) . ";\n";
                    print $fh "    end\n";
                }
                # 默认情况
                print $fh "    else begin\n";
                print $fh "        rdDataSel = ${num_sel_bits}'d" . ($num_mems + 1) . ";\n";
                print $fh "    end\n";
                print $fh "end\n\n";
                # 使用case语句选择数据
                print $fh "always\@(*) begin\n";
                print $fh "    case(rdDataSel)\n";
                print $fh "        ${num_sel_bits}'d0:rdData = $current_data[0];\n";
                for (my $mem_idx = 0; $mem_idx < $num_mems; $mem_idx++) {
                    my $mem = $memories[$mem_idx];
                    my $mem_name = $mem->{name};
                    print $fh "        ${num_sel_bits}'d" . ($mem_idx + 1) . ":rdData = ${mem_name}RdDataTemp;\n";
                }
                print $fh "        default:rdData = rdAddrErrData;\n";
                print $fh "    endcase\n";
                print $fh "end\n\n";
                
                # 对于单组情况，ack需要包含内存的ack
                my @mem_ack_exprs = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    push @mem_ack_exprs, "${mem_name}RdAck || (${mem_name}RdHit && !${mem_name}Rd)";
                }
                my $ack_expr = "$current_hits[0]";
                if (@mem_ack_exprs > 0) {
                    $ack_expr .= " || " . join(" || ", @mem_ack_exprs);
                }
                print $fh "assign rdAck = $ack_expr;\n";
            } else {
                print $fh "assign rdData = ${current_hits[0]} ? $current_data[0] : rdAddrErrData;\n\n";
                print $fh "assign rdAck = $current_hits[0];\n";
            }
            # 单组情况的err需要包含内存错误
            if (@memories > 0) {
                my @mem_err_signals = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    push @mem_err_signals, "${mem_name}RdErr";
                }
                if (@mem_err_signals > 0) {
                    my $err_expr = "$current_errs[0] || " . join(" || ", @mem_err_signals);
                    print $fh "assign rdErr = $err_expr;\n\n";
                } else {
                    print $fh "assign rdErr = $current_errs[0];\n\n";
                }
            } else {
                print $fh "assign rdErr = $current_errs[0];\n\n";
            }
        } else {
            # 没有任何组的情况，需要处理内存读取
            if (@memories > 0) {
                my @mem_conditions = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    # 使用memRdAck||memRdHitReal来选择内存数据，HitReal表示Hit有效且无错误
                    push @mem_conditions, "(${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : ";
                }
                if (@memories == 1) {
                    my $mem_name = $memories[0]->{name};
                    print $fh "assign rdData = (${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : rdAddrErrData;\n\n";
                } else {
                    my $default_expr = join("", @mem_conditions) . "rdAddrErrData";
                    print $fh "assign rdData = " . $default_expr . ";\n\n";
                }
                
                my @mem_ack_exprs = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    push @mem_ack_exprs, "${mem_name}RdAck || (${mem_name}RdHit && !${mem_name}Rd)";
                }
                if (@mem_ack_exprs > 0) {
                    my $ack_expr = join(" || ", @mem_ack_exprs);
                    print $fh "assign rdAck = $ack_expr;\n";
                } else {
                    print $fh "assign rdAck = 1'd0;\n";
                }
            } else {
                print $fh "assign rdData = rdAddrErrData;\n\n";
                print $fh "assign rdAck = 1'd0;\n";
            }
            print $fh "assign rdErr = 1'd0;\n\n";
        }
        
    } elsif ($total_groups == 1) {
        my $group_id = (keys %all_groups_for_decl)[0];
        print $fh "always\@(*) begin\n";
        print $fh "    if(rdHitLevel0_$group_id) begin\n";
        print $fh "        rdData = rdDataLevel0_$group_id;\n";
        print $fh "    end else begin\n";
        # else分支需要处理内存读取
        if (@memories > 0) {
            if (@memories == 1) {
                my $mem_name = $memories[0]->{name};
                # 使用memRdAck||memRdHitReal来选择内存数据，HitReal表示Hit有效且无错误
                print $fh "        rdData = (${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : rdAddrErrData;\n";
            } else {
                my @mem_conditions = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    # 使用memRdAck||memRdHitReal来选择内存数据，HitReal表示Hit有效且无错误
                    push @mem_conditions, "(${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : ";
                }
                my $default_expr = join("", @mem_conditions) . "rdAddrErrData";
                print $fh "        rdData = " . $default_expr . ";\n";
            }
        } else {
            print $fh "        rdData = rdAddrErrData;\n";
        }
        print $fh "    end\n";
        print $fh "end\n\n";
        
        # 对于单组情况，需要考虑内存的ack信号
        my @mem_ack_signals = ();
        for my $mem (@memories) {
            my $name = $mem->{name};
            push @mem_ack_signals, "${name}RdAck || (${name}RdHit && !${name}Rd)";
        }
        
        # 对于单组情况，直接使用组合逻辑输出（不使用打拍）
        if (@mem_ack_signals > 0) {
            my $ack_expr = "rdHitLevel0_$group_id || (" . join(" || ", @mem_ack_signals) . ")";
            print $fh "assign rdAck = $ack_expr;\n";
        } else {
            print $fh "assign rdAck = rdHitLevel0_$group_id;\n";
        }
        print $fh "assign rdErr = rdLevel0_${group_id}Err;\n\n";
    } else {
        # 完全没有组的情况，只处理内存读取
        if (@memories > 0) {
            if (@memories == 1) {
                my $mem_name = $memories[0]->{name};
                # 使用memRdAck||memRdHitReal来选择内存数据，HitReal表示Hit有效且无错误
                print $fh "always\@(*) begin\n";
                print $fh "    rdData = (${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : rdAddrErrData;\n";
                print $fh "end\n\n";
            } else {
                my @mem_conditions = ();
                for my $mem (@memories) {
                    my $mem_name = $mem->{name};
                    # 使用memRdAck||memRdHitReal来选择内存数据，HitReal表示Hit有效且无错误
                    push @mem_conditions, "(${mem_name}RdAck || ${mem_name}RdHitReal) ? ${mem_name}RdDataTemp : ";
                }
                my $default_expr = join("", @mem_conditions) . "rdAddrErrData";
                print $fh "always\@(*) begin\n";
                print $fh "    rdData = " . $default_expr . ";\n";
                print $fh "end\n\n";
            }
            
            my @mem_ack_signals = ();
            for my $mem (@memories) {
                my $name = $mem->{name};
                push @mem_ack_signals, "${name}RdAck || (${name}RdHit && !${name}Rd)";
            }
            
            print $fh "always\@(posedge clock or negedge rstN)begin\n";
            print $fh "    if(!rstN)begin\n";
            print $fh "        rdAck <= 1'd0;\n";
            print $fh "        rdErr <= 1'd0;\n";
            print $fh "    end\n";
            print $fh "    else begin\n";
            if (@mem_ack_signals > 0) {
                my $ack_line = "        rdAck <= " . join(" || ", @mem_ack_signals) . ";";
                print $fh format_long_line($ack_line, "        ", 128);
            } else {
                print $fh "        rdAck <= 1'd0;\n";
            }
            print $fh "        rdErr <= 1'd0;\n";
            print $fh "    end\n";
            print $fh "end\n\n";
        } else {
            print $fh "always\@(*) begin\n";
            print $fh "    rdData = rdAddrErrData;\n";
            print $fh "end\n\n";
            
            print $fh "always\@(posedge clock or negedge rstN)begin\n";
            print $fh "    if(!rstN)begin\n";
            print $fh "        rdAck <= 1'd0;\n";
            print $fh "        rdErr <= 1'd0;\n";
            print $fh "    end\n";
            print $fh "    else begin\n";
            print $fh "        rdAck <= 1'd0;\n";
            print $fh "        rdErr <= 1'd0;\n";
            print $fh "    end\n";
            print $fh "end\n\n";
        }
    }
    
    # 生成Write部分
    print $fh "//Write Part\n\n";
    
    # Write hit信号（只为有寄存器的组生成）
    print $fh "always\@(posedge clock or negedge rstN)begin\n";
    print $fh "    if(!rstN)begin\n";
    # 只为有寄存器的组初始化write hit信号
    for my $group_id (sort { $a <=> $b } keys %all_groups_for_decl) {
        if (exists $level0_groups{$group_id} && @{$level0_groups{$group_id}} > 0) {
            print $fh "        wrHitLevel0_$group_id <= 1'd0;\n";
        }
    }
    # 初始化内存的write hit信号
    for my $mem (@memories) {
        my $name = $mem->{name};
        print $fh "        ${name}WrHit <= 1'd0;\n";
    }
    print $fh "    end\n";
    print $fh "    else begin\n";
    # 为寄存器生成level0 hit信号（使用地址[31:6]）
    for my $group_id (sort { $a <=> $b } keys %all_groups_for_decl) {
        # 只对有寄存器的组生成hit信号
        if (exists $level0_groups{$group_id} && @{$level0_groups{$group_id}} > 0) {
            my $group_addr = ($group_id << 6);
            # 计算需要的位宽：最大地址组ID的位数
            my @all_group_ids = sort { $b <=> $a } keys %all_groups_for_decl;
            my $max_group = $all_group_ids[0];
            my $bits_needed = length(sprintf("%b", $max_group));
            if ($bits_needed < 1) { $bits_needed = 1; }
            my $addr_check = sprintf("((wrAddr[31:6] == %d'h%x)", 26, $group_id);
            print $fh "        wrHitLevel0_$group_id <= wr && $addr_check);\n";
        }
    }
    
    # 为每个内存生成单独的write hit信号（使用基地址比较）
    for my $mem (@memories) {
        my $name = $mem->{name};
        my $addr_compare_high = $mem->{addr_compare_high};
        my $addr_compare_low = $mem->{addr_compare_low};
        my $addr_compare_width = $mem->{addr_compare_width};
        my $addr_compare_value = $mem->{addr_compare_value};
        print $fh "        ${name}WrHit <= wr && (wrAddr[$addr_compare_high:$addr_compare_low] == ${addr_compare_width}'h" . sprintf("%x", $addr_compare_value) . ");\n";
    }
    print $fh "    end\n";
    print $fh "end\n\n";
    
    # 生成write ack和err（write ack包含有寄存器的组和内存的写命中信号）
    # 过滤掉只有内存没有寄存器的组
    my @wr_hit_signals = map { "wrHitLevel0_$_" } sort { $a <=> $b } grep { exists $level0_groups{$_} && @{$level0_groups{$_}} > 0 } keys %level0_groups;
    # 添加内存的写命中信号
    for my $mem (@memories) {
        my $name = $mem->{name};
        push @wr_hit_signals, "${name}WrHit";
    }
    if (@wr_hit_signals > 0) {
        my $assign_line = "assign wrAck = " . join(" || ", @wr_hit_signals) . ";";
        print $fh format_long_line($assign_line, "    ", 128);
    } else {
        print $fh "assign wrAck = 1'd0;\n";
    }
    
    # 收集有内存的组
    my %groups_with_memory = ();
    for my $mem (@memories) {
        my $mem_group_id = $mem->{level0_group};
        $groups_with_memory{$mem_group_id} = [] unless exists $groups_with_memory{$mem_group_id};
        push @{$groups_with_memory{$mem_group_id}}, $mem;
    }
    
    # 为所有level0组生成write decode逻辑或err逻辑（只包括有寄存器的组）
    for my $group_id (sort { $a <=> $b } keys %all_groups_for_decl) {
        # 跳过只有内存没有寄存器的组
        if (!exists $level0_groups{$group_id} || @{$level0_groups{$group_id}} == 0) {
            next;
        }
        
        # 处理有寄存器的组
        my $group_regs = $level0_groups{$group_id};
        
        # 创建decode映射，只包含可写的寄存器
        my %decode_map = ();
        for my $reg (@$group_regs) {
            my $idx = $reg->{decode_index};
            my $type = $reg->{type};
            # 只处理可写的寄存器类型（RWI 只写触发，不写存储）
            if ($type eq 'WO' || $type eq 'RW' || $type eq 'WI' || $type eq 'RIWI' || $type eq 'RIW') {
                $decode_map{$idx} = $reg;
            }
            # RWI 类型：可写触发，但不写存储，需要在 err 逻辑中允许写入
            if ($type eq 'RWI') {
                $decode_map{$idx} = $reg;  # 添加到 decode_map 以便在 err 逻辑中允许写入
            }
        }
        
        # 如果没有任何可写寄存器，检查是否有内存
        if (scalar(keys %decode_map) == 0) {
            # 如果这个组有内存，需要根据内存的decode_index生成err逻辑
            if (exists $groups_with_memory{$group_id}) {
                my @group_mems = @{$groups_with_memory{$group_id}};
                # 对于有内存但没有可写寄存器的组，生成write decode逻辑
                print $fh "assign wrDecodeLevel0_$group_id = wrAddrF1[5:2];\n";
                print $fh "always\@(*) begin\n";
                print $fh "    wrLevel0_${group_id}Err = 1'd0;\n";
                print $fh "    case(wrDecodeLevel0_$group_id)\n";
                
                # 为每个内存的decode_index添加case分支（err设为0，因为内存允许写入）
                for my $mem (@group_mems) {
                    my $decode_index = $mem->{decode_index};
                    print $fh "        4'd$decode_index:wrLevel0_${group_id}Err = 1'd0;\n";
                }
                
                # 所有其他情况（不在内存的decode_index）都报错
                print $fh "        default:wrLevel0_${group_id}Err = wrHitLevel0_$group_id;\n";
                print $fh "    endcase\n";
                print $fh "end\n";
            } else {
                # 既没有可写寄存器也没有内存，是空白区域，任何写入都报错
                print $fh "assign wrLevel0_${group_id}Err = wrHitLevel0_$group_id;\n";
            }
            next;
        }
        
        print $fh "assign wrDecodeLevel0_$group_id = wrAddrF1[5:2];\n";
        print $fh "always\@(*) begin\n";
        print $fh "    case(wrDecodeLevel0_$group_id)\n";
        
        # 生成实际存在的可写寄存器的case分支（err设为0）
        for my $idx (sort { $a <=> $b } keys %decode_map) {
            print $fh "        4'd$idx:wrLevel0_${group_id}Err = 1'd0;\n";
        }
        
        # 如果这个组还有内存，也要为内存的decode_index添加case分支（err设为0）
        if (exists $groups_with_memory{$group_id}) {
            my @group_mems = @{$groups_with_memory{$group_id}};
            for my $mem (@group_mems) {
                my $decode_index = $mem->{decode_index};
                # 如果内存的decode_index不在decode_map中（避免重复），添加case分支
                if (!exists $decode_map{$decode_index}) {
                    print $fh "        4'd$decode_index:wrLevel0_${group_id}Err = 1'd0;\n";
                }
            }
        }
        
        # 所有其他情况（不可写或不存在）都合并到default中
        print $fh "        default:wrLevel0_${group_id}Err = wrHitLevel0_$group_id;\n";
        print $fh "    endcase\n";
        print $fh "end\n";
        
        # 生成write数据存储逻辑
        # 检查是否有RW或WO类型的寄存器且有默认值（需要复位）
        my @regs_with_reset = ();
        for my $reg (@$group_regs) {
            my $type = $reg->{type};
            if (($type eq 'WO' || $type eq 'RW') && defined $reg->{default_value} && $reg->{default_value} ne "") {
                push @regs_with_reset, $reg;
            }
        }
        
        if (@regs_with_reset > 0) {
            # 有需要复位的寄存器，添加复位逻辑
            print $fh "always\@(posedge clock or negedge rstN) begin\n";
            print $fh "    if(!rstN)begin\n";
            for my $reg (@regs_with_reset) {
                my $name = $reg->{name};
                my $default_value = $reg->{default_value};
                print $fh "        $name <= $default_value;\n";
            }
            print $fh "    end\n";
            print $fh "    else begin\n";
            print $fh "        if(wrHitLevel0_$group_id)begin\n";
            print $fh "            case(wrDecodeLevel0_$group_id)\n";
            for my $reg (@$group_regs) {
                my $type = $reg->{type};
                my $idx = $reg->{decode_index};
                my $name = $reg->{name};
                
                if ($type eq 'WO' || $type eq 'RW') {
                    print $fh "                4'd$idx:$name             <= wrDataF1;\n";
                } elsif ($type eq 'WI' || $type eq 'RWI') {
                    print $fh "                4'd$idx:${name}WrData        <= wrDataF1;\n";
                } elsif ($type eq 'RIWI' || $type eq 'RIW') {
                    print $fh "                4'd$idx:${name}WrData        <= wrDataF1;\n";
                }
            }
            print $fh "                default:;\n";
            print $fh "            endcase\n";
            print $fh "        end\n";
            print $fh "    end\n";
            print $fh "end\n";
        } else {
            # 没有需要复位的寄存器，保持原有格式
            print $fh "always\@(posedge clock ) begin\n";
            print $fh "    if(wrHitLevel0_$group_id)begin\n";
            print $fh "        case(wrDecodeLevel0_$group_id)\n";
            for my $reg (@$group_regs) {
                my $type = $reg->{type};
                my $idx = $reg->{decode_index};
                my $name = $reg->{name};
                
                if ($type eq 'WO' || $type eq 'RW') {
                    print $fh "            4'd$idx:$name             <= wrDataF1;\n";
                } elsif ($type eq 'WI' || $type eq 'RWI') {
                    print $fh "            4'd$idx:${name}WrData        <= wrDataF1;\n";
                } elsif ($type eq 'RIWI' || $type eq 'RIW') {
                    print $fh "            4'd$idx:${name}WrData        <= wrDataF1;\n";
                }
            }
            print $fh "            default:;\n";
            print $fh "        endcase\n";
            print $fh "    end\n";
            print $fh "end\n";
        }
        
        # 生成write trigger逻辑
        my @wr_trigger_regs = ();
        for my $reg (@$group_regs) {
            my $type = $reg->{type};
            if ($type eq 'WI' || $type eq 'RWI' || $type eq 'RIWI') {
                push @wr_trigger_regs, $reg;
            }
        }
        
        if (@wr_trigger_regs > 0) {
            print $fh "always\@(posedge clock ) begin\n";
            for my $reg (@wr_trigger_regs) {
                my $wr_signal = $reg->{name};
                $wr_signal =~ s/^([a-z])/uc($1)/e;
                print $fh "    wr${wr_signal}        <= 1'd0;\n";
            }
            print $fh "    if(wrHitLevel0_$group_id) begin\n";
            print $fh "        case(wrDecodeLevel0_$group_id)\n";
            for my $reg (@wr_trigger_regs) {
                my $idx = $reg->{decode_index};
                my $wr_signal = $reg->{name};
                $wr_signal =~ s/^([a-z])/uc($1)/e;
                print $fh "            4'd$idx:wr${wr_signal}        <= 1'd1;\n";
            }
            print $fh "            default:;\n";
            print $fh "        endcase\n";
            print $fh "    end\n";
            print $fh "end\n\n";
        }
    }
    
    # 为每个内存生成写入逻辑
    for my $mem (@memories) {
        my $name = $mem->{name};
        my @fields = @{$mem->{fields}};
        my $group_id = $mem->{level0_group};
        my $offset_bits = $mem->{offset_bits};
        my $entry_idx_bits = $mem->{entry_idx_bits};
        my $entry_idx_low = $mem->{entry_idx_low};
        my $entry_idx_high = $mem->{entry_idx_high};
        my $offset_low = $mem->{offset_low};
        my $offset_high = $mem->{offset_high};
        my $last_offset = $mem->{last_offset};
        
        # 生成写入数据分配逻辑
        # 根据offset选择要写入的字段
        if ($offset_bits > 0) {
            print $fh "assign ${name}WrOffsetDecode = wrAddrF1[$offset_high:$offset_low];\n";
        }
        
        # 为每个字段生成写入逻辑
        # 根据TestReg.v，写入时根据offset选择要写入的字段
        print $fh "always\@(posedge clock ) begin\n";
        for my $field (@fields) {
            my $field_name = $field->{name};
            my $field_width = $field->{field_hi} - $field->{field_lo} + 1;
            my $field_offset = $field->{offset};
            # offset是字节偏移，OffsetDecode从地址[offset_high:offset_low]提取
            # OffsetDecode的值直接对应offset的值（offset就是用于匹配的值）
            my $offset_val = $field_offset;
            
            if ($offset_bits > 0) {
                print $fh "    if(${name}WrHit && ${name}WrOffsetDecode == ${offset_bits}'d$offset_val) begin\n";
            } else {
                print $fh "    if(${name}WrHit) begin\n";
            }
            
            # 从wrDataF1中提取对应字段的位
            # field_lo和field_hi是字段在Entry中的绝对位位置（0-31）
            # offset是字节偏移，需要计算字段在32位字中的位置
            # field_offset % 4 给出在4字节对齐的字中的字节偏移（0-3）
            # 直接使用field_lo和field_hi作为位位置（已经是相对于Entry起始的绝对位置）
            my $field_lo_in_word = $field->{field_lo};
            my $field_hi_in_word = $field->{field_hi};
            
            print $fh "        ${name}${field_name}WrData <= wrDataF1[$field_hi_in_word:$field_lo_in_word];\n";
            print $fh "    end\n";
        }
        print $fh "end\n\n";
        
        # 生成内存写入错误信号的赋值（变量已在Value部分声明）
        if ($offset_bits > 0 && @fields > 0) {
            my %offset_map = ();
            for my $field (@fields) {
                my $off = $field->{offset};
                $offset_map{$off} = 1;
            }
            my @sorted_offsets = sort { $a <=> $b } keys %offset_map;
            my @valid_conditions = ();
            for my $off (@sorted_offsets) {
                push @valid_conditions, "${name}WrOffsetDecode == ${offset_bits}'d$off";
            }
            print $fh "assign ${name}WrErr = ${name}WrHit && !(" . join(" || ", @valid_conditions) . ");\n\n";
        } else {
            print $fh "assign ${name}WrErr = 1'd0;\n\n";
        }
        
        # 生成memWr和memWrAddr信号
        # memWr在写入最后一个地址时有效
        # 对于内存，使用单独的hit信号，不需要wrHitLevel0_X条件
        if ($offset_bits > 0) {
            # offset是字节偏移，WrOffsetDecode的值直接对应offset的值
            my $last_offset_val = $last_offset;
            print $fh "assign ${name}WrInt = ${name}WrHit && (${name}WrOffsetDecode == ${offset_bits}'d$last_offset_val);\n";
        } else {
            print $fh "assign ${name}WrInt = ${name}WrHit;\n";
        }
        print $fh "assign ${name}WrAddrInt = wrAddrF1[$entry_idx_high:$entry_idx_low];\n";
        print $fh "always\@(posedge clock or negedge rstN)begin\n";
        print $fh "    if(!rstN)begin\n";
        print $fh "        ${name}Wr <= 1'd0;\n";
        print $fh "        ${name}WrAddr <= ${entry_idx_bits}'d0;\n";
        print $fh "    end\n";
        print $fh "    else begin\n";
        print $fh "        ${name}Wr <= ${name}WrInt;\n";
        print $fh "        ${name}WrAddr <= ${name}WrAddrInt;\n";
        print $fh "    end\n";
        print $fh "end\n\n";
    }
    
    # wrErr应该包含所有level0组的err信号（只包括有寄存器的组）和内存的写错误信号
    my @wr_err_signals = map { "wrLevel0_${_}Err" } sort { $a <=> $b } grep { exists $level0_groups{$_} && @{$level0_groups{$_}} > 0 } keys %all_groups_for_decl;
    # 添加内存的写错误信号
    for my $mem (@memories) {
        my $name = $mem->{name};
        push @wr_err_signals, "${name}WrErr";
    }
    if (@wr_err_signals > 0) {
        my $assign_line = "assign wrErr = " . join(" || ", @wr_err_signals) . ";";
        print $fh format_long_line($assign_line, "    ", 128);
    } else {
        print $fh "assign wrErr = 1'd0;\n";
    }
    print $fh "\n";
    
    print $fh "endmodule\n";
    
    close($fh);
}

# 主函数
my $file_arg = undef;

GetOptions(
    'f=s' => \$file_arg,
) or die "Usage: perl reg_rtl_generator.pl -f <Reg.txt_file>\n";

# 检查参数
if (!$file_arg) {
    die "Usage: perl reg_rtl_generator.pl -f <Reg.txt_file>\n" .
        "  -f <file>  : Parse a Reg.txt file, generate RTL Verilog file\n" .
        "Example: perl reg_rtl_generator.pl -f templates/templateReg.txt\n";
}

# 检查文件是否存在
unless (-f $file_arg) {
    die "Error: File not found: $file_arg\n";
}

# 解析输入文件
print "Parsing input file: $file_arg\n";
my ($registers_ref, $memories_ref) = parse_input_file($file_arg);
my @registers = @$registers_ref;
my @memories = defined $memories_ref ? @$memories_ref : ();
print "Found " . scalar(@registers) . " registers\n";
print "Found " . scalar(@memories) . " memories\n";

# 组织寄存器和内存
my ($level0_groups_ref, $registers_sorted_ref, $memories_sorted_ref) = organize_registers_by_decode($registers_ref, $memories_ref);

# 生成输出文件名：将.txt替换为.v
my $output_file = $file_arg;
$output_file =~ s/\.txt$/\.v/i;

# 生成模块名（基于输出文件名）
my $module_name = get_module_name($output_file);

# 生成RTL文件
print "Generating RTL file: $output_file\n";
generate_rtl($registers_sorted_ref, $level0_groups_ref, $module_name, $output_file, $memories_sorted_ref);

print "Done: $output_file\n";

