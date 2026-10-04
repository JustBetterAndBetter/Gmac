#!/usr/bin/env perl
# -*- coding: utf-8 -*-
# 寄存器描述文件解析器
# 解析基础描述文件，按照方案2规则分配地址，生成带地址的描述文件

use strict;
use warnings;
use utf8;
use Getopt::Long;
use File::Basename;
use File::Spec;
use File::Path qw(mkpath);

# 寄存器类型定义
my @REG_TYPES = qw(RO WO RW RI WI RIWI RIW RWI);

# 不能拼接的寄存器类型（需要单独占用地址空间）
# RO、WO、RW：因为访问特性不同不能拼接
# RI、WI、RIWI、RIW、RWI：因为会产生trigger信号，彼此之间不能拼接，每个寄存器必须单独占用地址空间
my @NON_MERGEABLE_TYPES = qw(RO WO RW RI WI RIWI RIW RWI);

# 可拼接的寄存器类型（当前没有，所有类型都不能拼接）
my @MERGEABLE_TYPES = ();

# 地址对齐：每个地址单元是4字节（32bit），但地址必须16字节对齐（最低两位为0）
# 因为一次读取4个字节，地址间隔是4字节，但地址本身必须16字节对齐
my $ADDR_ALIGN = 0x4;  # 寄存器之间的间隔
my $ADDR_BASE_ALIGN = 0x10;  # 地址基址对齐（16字节，最低两位为0）

# 每个地址单元的字节数（32bit = 4字节）
my $UNIT_SIZE = 4;

# 组间间隔
my $GROUP_SPACING = 0x100;

# 基址
my $BASE_ADDRESS = 0x00000000;

# 将数组转换为哈希以便快速查找
my %NON_MERGEABLE_TYPES = map { $_ => 1 } @NON_MERGEABLE_TYPES;
my %MERGEABLE_TYPES = map { $_ => 1 } @MERGEABLE_TYPES;
my %REG_TYPES = map { $_ => 1 } @REG_TYPES;

# 寄存器类
package Register;
sub new {
    my ($class, $name, $width, $reg_type, $description, $default_value) = @_;
    my $self = {
        name => $name,
        width => $width,
        type => $reg_type,
        description => $description,
        default_value => $default_value,
        address => undef,
        offset => undef,
        base_address => undef,
    };
    bless $self, $class;
    return $self;
}

# 表类
package Table;
sub new {
    my ($class, $name, $depth, $width, $description) = @_;
    my $self = {
        name => $name,
        depth => $depth,
        width => $width,
        description => $description,
        address => undef,
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

# 哈夫曼树节点类
package HuffmanNode;
sub new {
    my ($class, $weight, $registers, $left, $right) = @_;
    my $self = {
        weight => $weight,      # 权重（位宽总和）
        registers => $registers || [],  # 寄存器列表
        left => $left,
        right => $right,
    };
    bless $self, $class;
    return $self;
}

# 主程序包
package main;

# 格式化默认值：根据位宽生成格式化的默认值（如 32'h0, 1'h0）
sub format_default_value {
    my ($width) = @_;
    return "${width}'h0";
}

# 使用哈夫曼树算法优化可合并寄存器的地址分配
# 采用最优装箱策略，使用哈夫曼树思想：优先合并小的寄存器，最小化地址空间
# 在32bit（4字节）单元内按bit拼接，然后分配4字节对齐的地址
sub huffman_allocate_registers {
    my ($regs_ref) = @_;
    my @regs = @$regs_ref;
    
    return 0 if @regs == 0;
    
    # 如果只有一个寄存器，直接分配
    if (@regs == 1) {
        $regs[0]->{bit_offset} = 0;
        $regs[0]->{addr_offset} = 0;
        return $ADDR_ALIGN;
    }
    
    # 按位宽排序（从小到大），使用贪心算法结合哈夫曼树思想
    # 哈夫曼树的核心思想：频率（权重）小的节点应该放在树的底部
    # 对于寄存器分配：位宽小的寄存器应该优先打包，以最大化32bit单元的利用率
    my @sorted_regs = sort { $a->{width} <=> $b->{width} } @regs;
    
    # 使用装箱算法，采用最佳适配策略（Best Fit）结合哈夫曼树思想
    # 哈夫曼树思想：优先合并小的节点，最小化总编码长度
    # 对于寄存器分配：优先将小寄存器放入剩余bit空间最小的bin，最大化空间利用率
    my @bins = ();  # 每个bin代表一个32bit（4字节）地址单元
    my $addr_offset = 0;
    
    foreach my $reg (@sorted_regs) {
        my $best_bin = undef;
        my $best_remaining = 33;  # 初始化为大于32bit的值
        
        # 寻找最佳适配的bin（剩余bit空间最小但能容纳当前寄存器）
        foreach my $bin (@bins) {
            my $used_bits = 0;
            foreach my $r (@$bin) {
                $used_bits += $r->{width};
            }
            
            my $remaining = 32 - $used_bits;
            
            # 检查是否可以放入当前bin，且剩余bit空间最小
            if ($reg->{width} <= $remaining && $remaining < $best_remaining) {
                $best_bin = $bin;
                $best_remaining = $remaining;
            }
        }
        
        # 如果找到最佳bin，放入其中
        if (defined $best_bin) {
            my $used_bits = 0;
            foreach my $r (@$best_bin) {
                $used_bits += $r->{width};
            }
            $reg->{bit_offset} = $used_bits;
            $reg->{addr_offset} = $best_bin->[0]->{addr_offset};
            push @$best_bin, $reg;
        } else {
            # 如果无法放入现有bin，创建新的bin（4字节对齐地址）
            my $new_bin = [$reg];
            $reg->{bit_offset} = 0;
            $reg->{addr_offset} = $addr_offset;
            push @bins, $new_bin;
            $addr_offset += $ADDR_ALIGN;
        }
    }
    
    # 返回最大地址偏移（包括最后一个bin）
    return $addr_offset;
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
    while ($i < @lines) {
        my $line = $lines[$i];
        chomp($line);
        $line =~ s/^\s+|\s+$//g;
        
        # 跳过空行
        if (!$line) {
            $i++;
            next;
        }
        
        # 跳过注释行（以#开头）
        if ($line =~ /^#/) {
            $i++;
            next;
        }
        
        # 解析固定区域寄存器定义
        if ($line =~ /^RegFixFieldDefine:/) {
            $i++;
            # 跳过表头行和注释行
            while ($i < @lines && $lines[$i] !~ /^\s*name/) {
                my $check_line = $lines[$i];
                chomp($check_line);
                $check_line =~ s/^\s+|\s+$//g;
                # 如果是注释行，跳过
                if ($check_line =~ /^#/) {
                    $i++;
                    next;
                }
                # 如果是空行，跳过
                if (!$check_line) {
                    $i++;
                    next;
                }
                # 如果既不是表头也不是注释也不是空行，可能是其他内容，继续
                $i++;
            }
            if ($i >= @lines) {
                last;
            }
            $i++;
            
            # 解析固定寄存器行
            while ($i < @lines) {
                my $reg_line = $lines[$i];
                chomp($reg_line);
                $reg_line =~ s/^\s+|\s+$//g;
                if (!$reg_line) {
                    # 允许寄存器定义之间的空行，继续读取下一行
                    $i++;
                    next;
                }
                # 跳过注释行（以#开头）
                if ($reg_line =~ /^#/) {
                    $i++;
                    next;
                }
                # 检查是否是下一个section的开始
                if ($reg_line =~ /^RegFieldDefine:/ || $reg_line =~ /^MemFieldDefine:/ || $reg_line =~ /^MemName:/ || $reg_line =~ /^name\s+depth\s+width/i) {
                    last;
                }
                
                # 解析寄存器：name width type [defaultValue] description
                my @parts = split(/\s+/, $reg_line);
                if (@parts >= 4) {
                    my $name = $parts[0];
                    my $width = int($parts[1]);
                    my $reg_type = $parts[2];
                    my $default_value = undef;
                    my $description = '';
                    
                    # 检查第4列（parts[3]）是否是默认值格式
                    # 格式：name width type defaultValue description
                    # 或：name width type description（无默认值）
                    if (@parts >= 4) {
                        # 检查 parts[3] 是否是默认值格式（Verilog格式：位宽'进制值，如 32'h0, 1'b0, 16'd0）
                        # 匹配格式：数字'[hbd][0-9a-fA-FxXzZ_]+
                        if ($parts[3] =~ /^\d+'[hbd][0-9a-fA-FxXzZ_]+$/) {
                            # parts[3] 是默认值
                            $default_value = $parts[3];
                            # parts[4..$#parts] 是描述
                            if (@parts >= 5) {
                                $description = join(' ', @parts[4..$#parts]);
                            }
                        } else {
                            # parts[3] 不是默认值，那么 parts[3..$#parts] 都是描述
                            $description = join(' ', @parts[3..$#parts]);
                        }
                    }
                    
                    # 对于 WO 和 RW 类型，如果没有默认值，自动添加格式化的默认值
                    if (($reg_type eq 'WO' || $reg_type eq 'RW') && !defined($default_value)) {
                        $default_value = format_default_value($width);
                    }
                    
                    my $reg = Register->new($name, $width, $reg_type, $description, $default_value);
                    $reg->{is_fixed} = 1;  # 标记为固定寄存器
                    push @fixed_registers, $reg;
                }
                $i++;
            }
            next;
        }
        
        # 解析寄存器定义
        if ($line =~ /^RegFieldDefine:/) {
            $i++;
            # 跳过表头行和注释行
            while ($i < @lines && $lines[$i] !~ /^\s*name/) {
                my $check_line = $lines[$i];
                chomp($check_line);
                $check_line =~ s/^\s+|\s+$//g;
                # 如果是注释行，跳过
                if ($check_line =~ /^#/) {
                    $i++;
                    next;
                }
                # 如果是空行，跳过
                if (!$check_line) {
                    $i++;
                    next;
                }
                # 如果既不是表头也不是注释也不是空行，可能是其他内容，继续
                $i++;
            }
            if ($i >= @lines) {
                last;
            }
            $i++;
            
            # 解析寄存器行
            while ($i < @lines) {
                my $reg_line = $lines[$i];
                chomp($reg_line);
                $reg_line =~ s/^\s+|\s+$//g;
                if (!$reg_line) {
                    # 允许寄存器定义之间的空行，继续读取下一行
                    $i++;
                    next;
                }
                # 跳过注释行（以#开头）
                if ($reg_line =~ /^#/) {
                    $i++;
                    next;
                }
                # 检查是否是下一个section的开始（表定义或字段定义）
                if ($reg_line =~ /^MemFieldDefine:/ || $reg_line =~ /^MemName:/ || $reg_line =~ /^name\s+depth\s+width/i) {
                    last;
                }
                
                # 解析寄存器：name width type [defaultValue] description
                my @parts = split(/\s+/, $reg_line);
                if (@parts >= 4) {
                    my $name = $parts[0];
                    my $width = int($parts[1]);
                    my $reg_type = $parts[2];
                    my $default_value = undef;
                    my $description = '';
                    
                    # 检查第4列（parts[3]）是否是默认值格式
                    # 格式：name width type defaultValue description
                    # 或：name width type description（无默认值）
                    if (@parts >= 4) {
                        # 检查 parts[3] 是否是默认值格式（Verilog格式：位宽'进制值，如 32'h0, 1'b0, 16'd0）
                        # 匹配格式：数字'[hbd][0-9a-fA-FxXzZ_]+
                        if ($parts[3] =~ /^\d+'[hbd][0-9a-fA-FxXzZ_]+$/) {
                            # parts[3] 是默认值
                            $default_value = $parts[3];
                            # parts[4..$#parts] 是描述
                            if (@parts >= 5) {
                                $description = join(' ', @parts[4..$#parts]);
                            }
                        } else {
                            # parts[3] 不是默认值，那么 parts[3..$#parts] 都是描述
                            $description = join(' ', @parts[3..$#parts]);
                        }
                    }
                    
                    # 对于 WO 和 RW 类型，如果没有默认值，自动添加格式化的默认值
                    if (($reg_type eq 'WO' || $reg_type eq 'RW') && !defined($default_value)) {
                        $default_value = format_default_value($width);
                    }
                    
                    push @registers, Register->new($name, $width, $reg_type, $description, $default_value);
                }
                $i++;
            }
            next;
        }
        
        # 解析表定义（兼容两种写法：带MemFieldDefine标签或直接表头）
        if ($line =~ /^MemFieldDefine:/ || $line =~ /^name\s+depth\s+width/i) {
            # 如果当前行是标签，继续向下寻找表头
            if ($line =~ /^MemFieldDefine:/) {
                $i++;
                while ($i < @lines && $lines[$i] !~ /^\s*name\s+depth\s+width/i) {
                    my $check_line = $lines[$i];
                    chomp($check_line);
                    $check_line =~ s/^\s+|\s+$//g;
                    # 跳过注释行和空行
                    if ($check_line =~ /^#/ || !$check_line) {
                        $i++;
                        next;
                    }
                    $i++;
                }
                if ($i >= @lines) {
                    last;
                }
            }
            $i++;  # 跳过表头行
            
            # 解析表行
            while ($i < @lines) {
                my $table_line = $lines[$i];
                chomp($table_line);
                $table_line =~ s/^\s+|\s+$//g;
                if (!$table_line) {
                    # 允许表定义之间的空行，继续读取
                    $i++;
                    next;
                }
                # 跳过注释行（以#开头）
                if ($table_line =~ /^#/) {
                    $i++;
                    next;
                }
                # 检查是否是MemName开始
                if ($table_line =~ /^MemName:/) {
                    last;
                }
                
                # 解析表：name depth width description
                my @parts = split(/\s+/, $table_line);
                if (@parts >= 4) {
                    my $name = $parts[0];
                    my $depth = int($parts[1]);
                    my $width = int($parts[2]);
                    my $description = join(' ', @parts[3..$#parts]);
                    push @tables, Table->new($name, $depth, $width, $description);
                }
                $i++;
            }
            next;
        }
        
        # 解析表字段定义
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
            # 跳过表头行和注释行
            while ($i < @lines && $lines[$i] !~ /^\s*name/) {
                my $check_line = $lines[$i];
                chomp($check_line);
                $check_line =~ s/^\s+|\s+$//g;
                # 如果是注释行，跳过
                if ($check_line =~ /^#/) {
                    $i++;
                    next;
                }
                # 如果是空行，跳过
                if (!$check_line) {
                    $i++;
                    next;
                }
                # 如果既不是表头也不是注释也不是空行，可能是其他内容，继续
                $i++;
            }
            if ($i >= @lines) {
                last;
            }
            $i++;
            
            # 解析字段行
            while ($i < @lines && $current_table) {
                my $field_line = $lines[$i];
                chomp($field_line);
                $field_line =~ s/^\s+|\s+$//g;
                if (!$field_line) {
                    # 允许字段定义之间的空行，继续读取
                    $i++;
                    next;
                }
                # 跳过注释行（以#开头）
                if ($field_line =~ /^#/) {
                    $i++;
                    next;
                }
                
                # 检查是否是下一个MemName开始（下一个表的字段定义）
                if ($field_line =~ /^MemName:/) {
                    last;
                }
                
                # 检查是否是表头行（跳过）
                if ($field_line =~ /^\s*name\s+offset\s+fieldHi\s+fieldLo\s+description/i) {
                    $i++;
                    next;
                }
                
                # 解析字段：name offset fieldHi fieldLo description
                my @parts = split(/\s+/, $field_line);
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
            }
            next;
        }
        
        $i++;
    }
    
    return (\@fixed_registers, \@registers, \@tables);
}

sub allocate_addresses {
    my ($fixed_registers_ref, $registers_ref, $tables_ref) = @_;
    my @fixed_registers = @$fixed_registers_ref;
    my @registers = @$registers_ref;
    my @tables = @$tables_ref;
    
    # 固定区域：256字节（0x00000000 - 0x000000FF）
    my $FIXED_REGION_START = 0x00000000;
    my $FIXED_REGION_SIZE = 0x100;  # 256字节
    my $FIXED_REGION_END = $FIXED_REGION_START + $FIXED_REGION_SIZE - 1;
    
    # 为固定区域寄存器分配地址（从前到后依次排列，每个占用4字节）
    my $fixed_base = $FIXED_REGION_START;
    my $fixed_addr = $FIXED_REGION_START;
    foreach my $reg (@fixed_registers) {
        $reg->{base_address} = $fixed_base;
        $reg->{address} = $fixed_addr;
        $reg->{offset} = $fixed_addr - $fixed_base;  # 相对于固定区域基址的偏移
        $reg->{bit_offset} = 0;
        
        # 检查是否超出固定区域
        if ($fixed_addr + $ADDR_ALIGN - 1 > $FIXED_REGION_END) {
            die "Fixed region overflow: register $reg->{name} at address 0x" . sprintf("%08X", $fixed_addr) . " exceeds fixed region (0x00000000-0x000000FF)\n";
        }
        
        $fixed_addr += $ADDR_ALIGN;  # 每个寄存器占用4字节
    }
    
    # 普通寄存器从固定区域之后开始分配（0x00000100）
    my $current_addr = $FIXED_REGION_START + $FIXED_REGION_SIZE;
    
    # 按类型分组寄存器
    my %reg_groups = ();
    foreach my $reg (@registers) {
        if (!exists $REG_TYPES{$reg->{type}}) {
            die "Unknown register type: $reg->{type} for $reg->{name}\n";
        }
        push @{$reg_groups{$reg->{type}}}, $reg;
    }
    
    # 定义组顺序（用于输出时保持顺序）
    my @group_order = qw(RO WO RW RI WI RIWI RIW RWI);
    
    # 第一步：先计算每个组的大小（不分配地址）
    my @group_sizes = ();  # 存储 {type, regs_ref, size, order}
    my $order_idx = 0;
    foreach my $reg_type (@group_order) {
        if (!exists $reg_groups{$reg_type}) {
            next;
        }
        my @regs = @{$reg_groups{$reg_type}};
        if (@regs == 0) {
            next;
        }
        
        # 根据寄存器类型决定分配方式
        my $max_addr_offset;
        if (exists $NON_MERGEABLE_TYPES{$reg_type}) {
            # 不能拼接的类型：每个寄存器单独占用4字节地址单元
            $max_addr_offset = @regs * $ADDR_ALIGN;
        } else {
            # 可拼接的类型：使用哈夫曼树算法优化（按bit拼接到32bit内，4字节地址单元）
            $max_addr_offset = huffman_allocate_registers(\@regs);
        }
        
        # 对齐到16字节（最低两位为0）
        my $group_size = int(($max_addr_offset + $ADDR_BASE_ALIGN - 1) / $ADDR_BASE_ALIGN) * $ADDR_BASE_ALIGN;
        
        push @group_sizes, {
            type => $reg_type,
            regs_ref => \@regs,
            size => $group_size,
            order => $order_idx++
        };
    }
    
    # 第二步：使用哈夫曼树思想（最佳适配装箱）优化组之间的地址分配
    # 按组大小排序（从小到大），优先分配小组
    my @sorted_groups = sort { $a->{size} <=> $b->{size} } @group_sizes;
    my %group_base_addrs = ();  # 存储每个组的基址，用于输出时按原顺序
    
    # 为每个组分配地址
    foreach my $group_info (@sorted_groups) {
        my $reg_type = $group_info->{type};
        my @regs = @{$group_info->{regs_ref}};
        my $group_size = $group_info->{size};
        
        # 设置组基址（16字节对齐）
        my $base_addr = int(($current_addr + $ADDR_BASE_ALIGN - 1) / $ADDR_BASE_ALIGN) * $ADDR_BASE_ALIGN;
        
        # 保存组基址
        $group_base_addrs{$reg_type} = $base_addr;
        
        # 根据寄存器类型决定分配方式
        if (exists $NON_MERGEABLE_TYPES{$reg_type}) {
            # 不能拼接的类型：每个寄存器单独占用4字节地址单元
            my $offset = 0;
            foreach my $reg (@regs) {
                $reg->{base_address} = $base_addr;
                $reg->{address} = $base_addr + $offset;
                $reg->{offset} = $offset;
                $reg->{bit_offset} = 0;  # 在4字节单元内从bit 0开始
                $offset += $ADDR_ALIGN;  # 每个寄存器占用4字节
            }
        } else {
            # 可拼接的类型：使用哈夫曼树算法优化
            my $max_addr_offset = huffman_allocate_registers(\@regs);
            
            # 为每个寄存器设置地址信息
            foreach my $reg (@regs) {
                $reg->{base_address} = $base_addr;
                $reg->{address} = $base_addr + $reg->{addr_offset};
                $reg->{offset} = $reg->{addr_offset};
            }
        }
        
        # 更新当前地址：组基址 + 组大小（最小间隔为16字节）
        $current_addr = $base_addr + $group_size;
        # 确保下一个组的基址是16字节对齐的
        $current_addr = int(($current_addr + $ADDR_BASE_ALIGN - 1) / $ADDR_BASE_ALIGN) * $ADDR_BASE_ALIGN;
    }
    
    # 分配表地址，确保表的baseAddr是"整的"
    # 对于深度为depth，每个单元占据offset_count个偏移的表：
    # baseAddr[2+ceil(log2(depth))+ceil(log2(offset_count)):2] 必须为0
    # 其中：2表示地址最低2位（字节对齐），ceil(log2(depth))表示深度需要的bit数，
    # ceil(log2(offset_count))表示偏移数需要的bit数
    my $table_base = int(($current_addr + $ADDR_BASE_ALIGN - 1) / $ADDR_BASE_ALIGN) * $ADDR_BASE_ALIGN;
    foreach my $table (@tables) {
        # 计算每个单元占据的偏移数（最大offset + 1）
        my $max_offset = -1;
        foreach my $field (@{$table->{fields}}) {
            if ($field->{offset} > $max_offset) {
                $max_offset = $field->{offset};
            }
        }
        my $offset_count = $max_offset + 1;  # 每个单元占据的偏移数
        if ($offset_count < 1) {
            $offset_count = 1;  # 至少为1
        }
        
        # 计算深度需要的bit数（ceil(log2(depth))）
        # 对于深度depth，需要ceil(log2(depth))个bit来表示索引0到depth-1
        my $depth_bits = 0;
        if ($table->{depth} > 1) {
            # ceil(log2(n)) = int(log2(n-1)) + 1
            $depth_bits = int(log($table->{depth} - 1) / log(2)) + 1;
        }
        
        # 计算偏移数需要的bit数（ceil(log2(offset_count))）
        # 对于offset_count个偏移，需要ceil(log2(offset_count))个bit来表示偏移0到offset_count-1
        my $offset_bits = 0;
        if ($offset_count > 1) {
            # ceil(log2(n)) = int(log2(n-1)) + 1
            $offset_bits = int(log($offset_count - 1) / log(2)) + 1;
        }
        
        # 计算对齐要求：baseAddr[2+depth_bits+offset_bits:2] 必须为0
        # 即baseAddr必须对齐到 2^(2 + depth_bits + offset_bits) 字节
        my $align_bits = 2 + $depth_bits + $offset_bits;
        my $align_size = 1 << $align_bits;  # 2^(2 + depth_bits + offset_bits)
        
        # 对齐表基址
        $table_base = int(($table_base + $align_size - 1) / $align_size) * $align_size;
        $table->{address} = $table_base;
        
        # 计算表大小：深度 * 每个单元占据的偏移数 * 4字节
        my $table_size = $table->{depth} * $offset_count * 4;
        # 对齐到4字节
        $table_size = int(($table_size + $ADDR_ALIGN - 1) / $ADDR_ALIGN) * $ADDR_ALIGN;
        $table_base += $table_size;
    }
}

sub generate_output_file {
    my ($fixed_registers_ref, $registers_ref, $tables_ref, $output_filename) = @_;
    my @fixed_registers = @$fixed_registers_ref;
    my @registers = @$registers_ref;
    my @tables = @$tables_ref;
    
    open(my $fh, '>:encoding(utf8)', $output_filename) or die "Cannot open file $output_filename: $!";
    
    # 输出固定区域寄存器（如果有）
    if (@fixed_registers > 0) {
        # 表头前空行
        print $fh "\n";
        # 输出表头
        printf $fh "%-20s %-15s %-15s %-12s %-10s %-10s %-15s %-30s\n", 
            'name', 'address', 'offset', 'bit_range', 'width', 'type', 'defaultValue', 'description';
        # 输出分隔线（多个#）
        print $fh "########################################################################################################\n";
        
        # 输出固定寄存器数据
        foreach my $reg (@fixed_registers) {
            my $bit_offset = $reg->{bit_offset} || 0;
            my $bit_hi = $bit_offset + $reg->{width} - 1;
            my $bit_lo = $bit_offset;
            my $bit_range = "[$bit_hi:$bit_lo]";
            my $default_value = $reg->{default_value} || '';
            
            printf $fh "%-20s 0x%08X     0x%04X         %-12s %-10d %-10s %-15s %-30s\n",
                $reg->{name}, $reg->{address}, $reg->{offset}, 
                $bit_range, $reg->{width}, $reg->{type}, $default_value, $reg->{description};
        }
    }
    
    # 按类型分组普通寄存器
    my %reg_groups = ();
    foreach my $reg (@registers) {
        push @{$reg_groups{$reg->{type}}}, $reg;
    }
    
    # 定义组顺序
    my @group_order = qw(RO WO RW RI WI RIWI RIW RWI);
    
    # 收集所有普通寄存器并按地址排序
    my @all_regs = ();
    foreach my $reg_type (@group_order) {
        if (!exists $reg_groups{$reg_type}) {
            next;
        }
        my @regs = @{$reg_groups{$reg_type}};
        push @all_regs, @regs;
    }
    
    # 如果有普通寄存器，输出表头和数据
    if (@all_regs > 0) {
        # 按地址和bit偏移排序，便于阅读
        @all_regs = sort {
            (($a->{address} // 0) <=> ($b->{address} // 0))
                || (($a->{bit_offset} || 0) <=> ($b->{bit_offset} || 0))
        } @all_regs;
        
        # 表头前空行
        print $fh "\n";
        # 输出表头
        printf $fh "%-20s %-15s %-15s %-12s %-10s %-10s %-15s %-30s\n", 
            'name', 'address', 'offset', 'bit_range', 'width', 'type', 'defaultValue', 'description';
        # 输出分隔线（多个#）
        print $fh "########################################################################################################\n";
        
        # 输出普通寄存器数据
        foreach my $reg (@all_regs) {
            my $bit_offset = $reg->{bit_offset} || 0;
            my $bit_hi = $bit_offset + $reg->{width} - 1;
            my $bit_lo = $bit_offset;
            my $bit_range = "[$bit_hi:$bit_lo]";
            my $default_value = $reg->{default_value} || '';
            
            printf $fh "%-20s 0x%08X     0x%04X         %-12s %-10d %-10s %-15s %-30s\n",
                $reg->{name}, $reg->{address}, $reg->{offset}, 
                $bit_range, $reg->{width}, $reg->{type}, $default_value, $reg->{description};
        }
    }
    
    # 输出表组
    if (@tables > 0) {
        # 表头前空行
        print $fh "\n";
        # 输出表头
        printf $fh "%-20s %-15s %-10s %-10s %-30s\n",
            'name', 'address', 'depth', 'width', 'description';
        # 输出分隔线（多个#）
        print $fh "########################################################################################################\n";
        
        # 输出表数据
        foreach my $table (@tables) {
            printf $fh "%-20s 0x%08X     %-10d %-10d %-30s\n",
                $table->{name}, $table->{address}, $table->{depth},
                $table->{width}, $table->{description};
        }
        
        # 输出表字段定义（每个表单独输出）
        foreach my $table (@tables) {
            if (@{$table->{fields}} > 0) {
                # 表头前空行
                print $fh "\n";
                # 输出表名标识（只输出MemName:MemName格式）
                print $fh "MemName:$table->{name}\n";
                # 输出分隔线（多个#）
                print $fh "########################################################################################################\n";
                
                # 输出字段表头
                printf $fh "%-20s %-15s %-10s %-10s %-30s\n",
                    'name', 'offset', 'fieldHi', 'fieldLo', 'description';
                # 输出分隔线（多个#）
                print $fh "########################################################################################################\n";
                
                # 输出字段数据
                foreach my $field (@{$table->{fields}}) {
                    printf $fh "%-20s %-15d %-10d %-10d %-30s\n",
                        $field->{name}, $field->{offset}, $field->{field_hi},
                        $field->{field_lo}, $field->{description};
                }
            }
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
    
    # 获取文件路径和文件名（不含扩展名）
    my ($name, $dir, $ext) = fileparse($input_file, qr/\.[^.]*/);
    
    # 生成输出文件名：原文件名 + Reg.txt，放在同目录
    my $output_file = File::Spec->catfile($dir, "${name}Reg.txt");
    
    eval {
        # 解析输入文件
        print "Parsing input file: $input_file\n";
        my ($fixed_registers_ref, $registers_ref, $tables_ref) = parse_input_file($input_file);
        my @fixed_registers = @$fixed_registers_ref;
        my @registers = @$registers_ref;
        my @tables = @$tables_ref;
        print "Found " . scalar(@fixed_registers) . " fixed registers, " . scalar(@registers) . " registers and " . scalar(@tables) . " tables\n";
        
        # 分配地址
        print "Allocating addresses...\n";
        allocate_addresses($fixed_registers_ref, $registers_ref, $tables_ref);
        
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

# 处理目录下所有文件
sub process_directory {
    my ($dir_path) = @_;
    
    # 检查目录是否存在
    unless (-d $dir_path) {
        die "Error: Directory not found: $dir_path\n";
    }
    
    # 创建输出目录：目录路径/Reg
    my $output_dir = File::Spec->catdir($dir_path, "RegTxt");
    
    # 如果输出目录不存在，创建它
    unless (-d $output_dir) {
        print "Creating output directory: $output_dir\n";
        mkpath($output_dir) or die "Error: Cannot create directory $output_dir: $!\n";
    }
    
    # 打开目录
    opendir(my $dh, $dir_path) or die "Error: Cannot open directory $dir_path: $!\n";
    
    my @files = grep { -f File::Spec->catfile($dir_path, $_) } readdir($dh);
    closedir($dh);
    
    if (@files == 0) {
        print "No files found in directory: $dir_path\n";
        return;
    }
    
    print "Found " . scalar(@files) . " files in directory: $dir_path\n";
    
    my $success_count = 0;
    my $fail_count = 0;
    
    foreach my $file (@files) {
        my $input_file = File::Spec->catfile($dir_path, $file);
        
        # 获取文件名（不含扩展名）
        my ($name, $dir, $ext) = fileparse($input_file, qr/\.[^.]*/);
        
        # 生成输出文件名：原文件名 + Reg.txt，放在输出目录
        my $output_file = File::Spec->catfile($output_dir, "${name}Reg.txt");
        
        eval {
            # 解析输入文件
            print "\nProcessing: $input_file\n";
            my ($fixed_registers_ref, $registers_ref, $tables_ref) = parse_input_file($input_file);
            my @fixed_registers = @$fixed_registers_ref;
            my @registers = @$registers_ref;
            my @tables = @$tables_ref;
            print "Found " . scalar(@fixed_registers) . " fixed registers, " . scalar(@registers) . " registers and " . scalar(@tables) . " tables\n";
            
            # 分配地址
            print "Allocating addresses...\n";
            allocate_addresses($fixed_registers_ref, $registers_ref, $tables_ref);
            
            # 生成输出文件
            print "Generating output file: $output_file\n";
            generate_output_file($fixed_registers_ref, $registers_ref, $tables_ref, $output_file);
            
            print "Done: $output_file\n";
            $success_count++;
        };
        
        if ($@) {
            print "Error processing $input_file: $@\n";
            $fail_count++;
        }
    }
    
    print "\nSummary: $success_count files processed successfully, $fail_count files failed\n";
}

# 主函数
my $file_arg = undef;
my $dir_arg = undef;

GetOptions(
    'f=s' => \$file_arg,
    'd=s' => \$dir_arg,
) or die "Usage: perl reg_parser.pl -f <input_file> | -d <directory>\n";

# 检查参数
if ($file_arg && $dir_arg) {
    die "Error: Cannot use both -f and -d options at the same time\n";
}

if (!$file_arg && !$dir_arg) {
    die "Usage: perl reg_parser.pl -f <input_file> | -d <directory>\n" .
        "  -f <file>  : Parse a single file, generate <filename>Reg.txt in the same directory\n" .
        "  -d <dir>   : Parse all files in a directory, generate files in <dir>/Reg/\n" .
        "Example: perl reg_parser.pl -f template\n" .
        "Example: perl reg_parser.pl -d ./reg_definitions\n";
}

if ($file_arg) {
    # 处理单个文件
    process_single_file($file_arg);
} elsif ($dir_arg) {
    # 处理目录
    process_directory($dir_arg);
}

