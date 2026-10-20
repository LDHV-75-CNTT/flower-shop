-- Chạy toàn bộ file này trong Supabase > SQL Editor
create table profiles(id uuid primary key references auth.users on delete cascade,full_name text,phone text,role text not null default 'customer' check(role in('admin','customer')),created_at timestamptz default now());
create table categories(id serial primary key,name text not null);
create table products(id serial primary key,name text not null,description text,price numeric not null check(price>=0),sale_price numeric check(sale_price>=0),image_url text,category_id int references categories on delete set null,season smallint check(season between 1 and 4),holiday text,stock int not null default 0 check(stock>=0),featured bool default false,bestseller bool default false,active bool default true,created_at timestamptz default now());
create table orders(id uuid primary key default gen_random_uuid(),user_id uuid references auth.users,name text,phone text,address text,note text,total numeric not null default 0,discount numeric not null default 0,status text not null default 'pending' check(status in('pending','confirmed','shipping','delivered','cancelled')),payment_status text not null default 'unpaid' check(payment_status in('unpaid','paid','refunded')),created_at timestamptz default now());
create table order_items(id serial primary key,order_id uuid references orders on delete cascade,product_id int references products,name text,price numeric,qty int check(qty>0));
create function is_admin() returns bool language sql security definer stable set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
create function new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into profiles(id,full_name) values(new.id,new.raw_user_meta_data->>'full_name'); return new; end $$;
create trigger on_auth_user after insert on auth.users for each row execute function new_user();
alter table profiles enable row level security;alter table categories enable row level security;alter table products enable row level security;alter table orders enable row level security;alter table order_items enable row level security;
create policy p_sel on profiles for select using(id=auth.uid() or is_admin());
create policy p_upd on profiles for update using(id=auth.uid()) with check(id=auth.uid());
revoke update on profiles from anon,authenticated;grant update(full_name,phone) on profiles to authenticated; -- khách không thể tự nâng quyền
create policy c_sel on categories for select using(true);
create policy c_all on categories for all using(is_admin()) with check(is_admin());
create policy pr_sel on products for select using(active or is_admin());
create policy pr_all on products for all using(is_admin()) with check(is_admin());
create policy o_sel on orders for select using(user_id=auth.uid() or is_admin());
create policy o_upd on orders for update using(is_admin()) with check(is_admin());
create policy oi_sel on order_items for select using(is_admin() or exists(select 1 from orders o where o.id=order_id and o.user_id=auth.uid()));
-- Không có policy INSERT cho orders/order_items: khách chỉ đặt hàng qua hàm place_order (giá và tồn kho tính ở máy chủ)
create function place_order(p_name text,p_phone text,p_address text,p_note text,p_items jsonb,p_code text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare oid uuid;it jsonb;pr products;tot numeric:=0;q int;pct int:=0;
begin
 if auth.uid() is null then raise exception 'Cần đăng nhập'; end if;
 if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' or coalesce(trim(p_address),'')='' then raise exception 'Thiếu thông tin giao hàng'; end if;
 insert into orders(user_id,name,phone,address,note) values(auth.uid(),p_name,p_phone,p_address,p_note) returning id into oid;
 for it in select * from jsonb_array_elements(p_items) loop
  q:=(it->>'qty')::int; select * into pr from products where id=(it->>'id')::int and active for update;
  if not found or q<=0 then raise exception 'Sản phẩm không hợp lệ'; end if;
  if pr.stock<q then raise exception 'Không đủ hàng: %',pr.name; end if;
  update products set stock=stock-q where id=pr.id;
  insert into order_items(order_id,product_id,name,price,qty) values(oid,pr.id,pr.name,coalesce(pr.sale_price,pr.price),q);
  tot:=tot+coalesce(pr.sale_price,pr.price)*q;
 end loop;
 if p_code is not null and trim(p_code)<>'' then select percent into pct from coupons where code=upper(trim(p_code)) and active; if not found then raise exception 'Mã giảm giá không hợp lệ'; end if; end if;
 update orders set discount=round(tot*pct/100),total=tot-round(tot*pct/100) where id=oid; return oid;
end $$;
create function restock() returns trigger language plpgsql security definer set search_path=public as $$ begin if new.status='cancelled' and old.status<>'cancelled' then update products p set stock=p.stock+i.qty from order_items i where i.order_id=new.id and p.id=i.product_id; end if; return new; end $$;
create trigger t_restock after update on orders for each row execute function restock();
insert into storage.buckets(id,name,public) values('products','products',true) on conflict do nothing;
create policy img_read on storage.objects for select using(bucket_id='products');
create policy img_admin on storage.objects for all using(bucket_id='products' and is_admin()) with check(bucket_id='products' and is_admin());
insert into categories(name) values('Hoa bó'),('Hoa chậu'),('Quà trang trí');
create table coupons(id serial primary key,code text unique not null,percent int not null check(percent between 1 and 100),active bool not null default true);
create table holidays(id serial primary key,name text unique not null);
create table cart_items(user_id uuid references auth.users on delete cascade,product_id int references products on delete cascade,qty int not null check(qty>0),primary key(user_id,product_id));
create table inventory_transactions(id serial primary key,product_id int references products on delete cascade,change int not null,reason text,created_at timestamptz default now());
alter table coupons enable row level security;alter table holidays enable row level security;alter table cart_items enable row level security;alter table inventory_transactions enable row level security;
create policy cp_all on coupons for all using(is_admin()) with check(is_admin());
create policy h_sel on holidays for select using(true);
create policy h_all on holidays for all using(is_admin()) with check(is_admin());
create policy ci_all on cart_items for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy inv_sel on inventory_transactions for select using(is_admin());
create function check_coupon(p_code text) returns int language sql security definer stable set search_path=public as $$ select percent from coupons where code=upper(trim(p_code)) and active $$;
create function log_stock() returns trigger language plpgsql security definer set search_path=public as $$ begin if new.stock<>old.stock then insert into inventory_transactions(product_id,change,reason) values(new.id,new.stock-old.stock,case when is_admin() then 'điều chỉnh / hủy đơn' else 'đặt hàng' end); end if; return new; end $$;
create trigger t_log_stock after update on products for each row execute function log_stock();
-- Chỉ lộ số lượng đã bán (tổng hợp) để xếp hạng "Bán chạy", không lộ dữ liệu đơn hàng
create view product_sales as select oi.product_id,sum(oi.qty)::int as sold from order_items oi join orders o on o.id=oi.order_id where o.status='delivered' and o.payment_status<>'refunded' group by oi.product_id;
grant select on product_sales to anon,authenticated;
insert into holidays(name) values('Tết Dương lịch'),('Tết Nguyên đán'),('Valentine 14/2'),('Quốc tế Phụ nữ 8/3'),('Ngày của Mẹ'),('Quốc tế Thiếu nhi 1/6'),('Phụ nữ Việt Nam 20/10'),('Nhà giáo Việt Nam 20/11'),('Giáng sinh'),('Sinh nhật'),('Khai trương'),('Tốt nghiệp'),('Kỷ niệm');
create function cancel_order(p_id uuid) returns void language plpgsql security definer set search_path=public as $$ begin update orders set status='cancelled' where id=p_id and user_id=auth.uid() and status='pending'; if not found then raise exception 'Không thể hủy đơn này'; end if; end $$;
